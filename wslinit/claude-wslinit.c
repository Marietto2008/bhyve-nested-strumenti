/*
 * claude-wslinit.c -- Claude 03/11/2026. Init minimale di FreeBSD per la VM di WSL2, traguardo I1: fare accettare la
 * VM dal servizio WSL (niente piu' CreateVm/ERROR_TIMEOUT). Riproduce l'avvio di mini_init (src/linux/init/main.cpp):
 *   1. connessione hvsocket alla porta 50000 (canale principale), messaggio GuestCapabilities;
 *   2. seconda connessione (canale delle notifiche);
 *   3. riceve i messaggi del servizio; EarlyConfig -> connessione GNS (+ DNS se richiesto);
 *      InitialConfig -> connessione del port tracker se richiesto.
 * Ogni messaggio ricevuto viene descritto su stderr (che rc manda sulla console).
 * Formato dei messaggi: MESSAGE_HEADER {tipo, dimensione, TransactionId, TransactionStep}; i messaggi fuori
 * transazione hanno step 0 e id = contatore per direzione che parte da 1 (SocketChannel.h).
 */
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/utsname.h>
#include <err.h>
#include <errno.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifndef AF_HYPERV
#define AF_HYPERV 43
#endif

/* da sys/dev/hyperv/hvsock/hv_sock.h */
struct sockaddr_hvs {
	unsigned char	sa_len;
	sa_family_t	sa_family;
	unsigned int	hvs_port;
	unsigned char	hvs_zero[sizeof(struct sockaddr) - sizeof(sa_family_t) - sizeof(unsigned char) -
	    sizeof(unsigned int)];
};

#define WSL_INIT_PORT		50000

/* valori di LX_MESSAGE_TYPE (src/shared/inc/lxinitshared.h, b6fea0ff) */
#define MSG_LAUNCH_INIT		29
#define MSG_EARLY_CONFIG	36
#define MSG_INITIAL_CONFIG	37
#define MSG_GUEST_CAPABILITIES	43

struct msg_header {
	uint32_t type;
	uint32_t size;
	uint32_t transaction_id;
	uint32_t transaction_step;
};
_Static_assert(sizeof(struct msg_header) == 16, "MESSAGE_HEADER");

struct guest_capabilities {
	struct msg_header h;
	bool seccomp_available;
	bool ipv6_available;
	uint64_t swiotlb_base;
	uint64_t swiotlb_size;
	char buffer[];			/* versione del kernel */
};
_Static_assert(offsetof(struct guest_capabilities, swiotlb_base) == 24, "GuestCapabilities");

struct early_config {
	struct msg_header h;
	uint32_t swap_lun;
	uint32_t system_distro_device_type;
	uint32_t system_distro_device_id;
	uint32_t memory_reclaim_mode;
	uint32_t dns_tunneling_ip;
	bool enable_debug_shell;
	bool enable_dns_tunneling;
	bool enable_safe_mode;
	bool default_kernel;
	bool isolate_distro_cgroup;
	uint32_t kernel_modules_device_id;
	uint32_t hostname_offset;
	uint32_t kernel_modules_list_offset;
	char buffer[];
};
_Static_assert(offsetof(struct early_config, kernel_modules_device_id) == 44, "EarlyConfig");

struct networking_configuration {
	uint32_t networking_mode;
	uint32_t port_tracker_type;
	uint16_t ephemeral_start;
	uint16_t ephemeral_end;
	bool enable_dhcp_client;
	bool disable_ipv6;
	int32_t dhcp_timeout;
};
_Static_assert(sizeof(struct networking_configuration) == 20, "NetworkingConfiguration");

struct initial_config {
	struct msg_header h;
	int32_t entropy_size;
	uint32_t entropy_offset;
	bool enable_gui_apps;
	bool mount_gpu_shares;
	bool enable_inbox_gpu_libs;
	struct networking_configuration net;
	char buffer[];
};

static uint32_t sent_non_transaction;

static int
connect_host(unsigned int port)
{
	struct sockaddr_hvs sa;
	int fd;

	fd = socket(AF_HYPERV, SOCK_STREAM, 0);
	if (fd < 0)
		err(1, "socket(AF_HYPERV)");
	memset(&sa, 0, sizeof(sa));
	sa.sa_len = sizeof(sa);
	sa.sa_family = AF_HYPERV;
	sa.hvs_port = port;
	if (connect(fd, (struct sockaddr *)&sa, sizeof(sa)) < 0)
		err(1, "connect(porta %u)", port);
	warnx("collegato alla porta %u (fd %d)", port, fd);
	return (fd);
}

static void
write_all(int fd, const void *buf, size_t len)
{
	const char *p = buf;
	ssize_t n;

	while (len > 0) {
		n = write(fd, p, len);
		if (n < 0) {
			if (errno == EINTR)
				continue;
			err(1, "write");
		}
		p += n;
		len -= (size_t)n;
	}
}

/* legge esattamente len byte; false se il canale e' chiuso */
static bool
read_all(int fd, void *buf, size_t len)
{
	char *p = buf;
	ssize_t n;

	while (len > 0) {
		n = read(fd, p, len);
		if (n < 0) {
			if (errno == EINTR)
				continue;
			err(1, "read");
		}
		if (n == 0)
			return (false);
		p += n;
		len -= (size_t)n;
	}
	return (true);
}

static void
send_capabilities(int fd)
{
	struct utsname u;
	struct guest_capabilities *m;
	size_t len, size;

	char rel[sizeof(u.release) + 4];
	const char *p, *dash;
	int dots;

	if (uname(&u) < 0)
		err(1, "uname");
	/*
	 * Il servizio vuole tre numeri (regex "(\d+)\.(\d+)\.(\d+).*", ReadGuestCapabilities): con
	 * "15.2-PRERELEASE" chiudeva il canale. Si completa il terzo: "15.2.0-PRERELEASE".
	 */
	dash = strchr(u.release, '-');
	if (dash == NULL)
		dash = u.release + strlen(u.release);
	for (dots = 0, p = u.release; p < dash; p++)
		dots += (*p == '.');
	if (dots == 1)
		snprintf(rel, sizeof(rel), "%.*s.0%s", (int)(dash - u.release), u.release, dash);
	else
		snprintf(rel, sizeof(rel), "%s", u.release);
	len = strlen(rel) + 1;
	size = sizeof(*m) + len;
	m = calloc(1, size);
	if (m == NULL)
		err(1, "calloc");
	m->h.type = MSG_GUEST_CAPABILITIES;
	m->h.size = (uint32_t)size;
	m->h.transaction_id = ++sent_non_transaction;
	m->h.transaction_step = 0;
	m->seccomp_available = false;
	m->ipv6_available = true;
	memcpy(m->buffer, rel, len);
	write_all(fd, m, size);
	warnx("GuestCapabilities mandato (kernel %s, %zu byte)", rel, size);
	free(m);
}

int
main(void)
{
	struct msg_header h;
	char *msg;
	int fd, notify, extra;

	setvbuf(stderr, NULL, _IONBF, 0);
	warnx("avvio, pid %d", getpid());

	fd = connect_host(WSL_INIT_PORT);
	send_capabilities(fd);
	notify = connect_host(WSL_INIT_PORT);
	(void)notify;

	for (;;) {
		if (!read_all(fd, &h, sizeof(h))) {
			warnx("il servizio ha chiuso il canale principale");
			break;
		}
		if (h.size < sizeof(h) || h.size > 16 * 1024 * 1024)
			errx(1, "dimensione di messaggio non valida %u", h.size);
		msg = malloc(h.size);
		if (msg == NULL)
			err(1, "malloc");
		memcpy(msg, &h, sizeof(h));
		if (!read_all(fd, msg + sizeof(h), h.size - sizeof(h)))
			errx(1, "canale chiuso a meta' messaggio");
		warnx("messaggio tipo %u, %u byte, transazione %u passo %u", h.type, h.size,
		    h.transaction_id, h.transaction_step);

		switch (h.type) {
		case MSG_EARLY_CONFIG: {
			struct early_config *e = (struct early_config *)msg;

			warnx("EarlyConfig: swap lun %u, distro di sistema tipo %u id %u, dns tunneling %d, "
			    "debug shell %d", e->swap_lun, e->system_distro_device_type, e->system_distro_device_id,
			    e->enable_dns_tunneling, e->enable_debug_shell);
			if (e->hostname_offset > 0 && e->hostname_offset < h.size)
				warnx("EarlyConfig: hostname '%s'", msg + e->hostname_offset);
			extra = connect_host(WSL_INIT_PORT);	/* canale GNS */
			warnx("canale GNS fd %d", extra);
			if (e->enable_dns_tunneling) {
				extra = connect_host(WSL_INIT_PORT);
				warnx("canale DNS fd %d", extra);
			}
			break;
		}
		case MSG_INITIAL_CONFIG: {
			struct initial_config *c = (struct initial_config *)msg;

			warnx("InitialConfig: rete modo %u, port tracker %u, dhcp %d, gui %d",
			    c->net.networking_mode, c->net.port_tracker_type, c->net.enable_dhcp_client,
			    c->enable_gui_apps);
			if (c->net.port_tracker_type == 1 || c->net.port_tracker_type == 2) {
				extra = connect_host(WSL_INIT_PORT);
				warnx("canale port tracker fd %d", extra);
			}
			warnx("I1: inizializzazione della VM completata dal lato FreeBSD");
			break;
		}
		case MSG_LAUNCH_INIT:
			warnx("LaunchInit: avvio di una distro richiesto (traguardo I2, non ancora gestito)");
			break;
		default:
			warnx("tipo %u non gestito", h.type);
			break;
		}
		free(msg);
	}
	return (0);
}
