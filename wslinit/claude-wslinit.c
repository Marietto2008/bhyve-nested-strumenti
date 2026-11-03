/*
 * claude-wslinit.c -- Claude 03/11/2026. Init minimale di FreeBSD per la VM di WSL2.
 *
 * Traguardo I1 (raggiunto il 03/11, prova delle 16:11): fare accettare la VM dal servizio WSL. Riproduce l'avvio di
 * mini_init (src/linux/init/main.cpp):
 *   1. connessione hvsocket alla porta 50000 (canale principale), messaggio GuestCapabilities;
 *   2. seconda connessione (canale delle notifiche);
 *   3. riceve i messaggi del servizio; EarlyConfig -> connessione GNS (+ DNS se richiesto);
 *      InitialConfig -> connessione del port tracker se richiesto.
 *
 * Traguardo I2: far girare un comando di FreeBSD da wsl.exe. Riproduce la parte di init.cpp che serve:
 *   4. LaunchInit -> nuova connessione alla 50000 (canale dell'istanza) servita da un processo figlio, l'«init della
 *      distro»: manda CreateInstanceResult, poi risponde a Initialize, CreateSession, TimezoneInformation,
 *      TerminateInstance (WslCoreInstance.cpp);
 *   5. CreateSession -> porta in ascolto, il servizio vi si collega: processo «capo sessione»;
 *   6. CreateProcessUtilityVm sul canale della sessione -> porta in ascolto, il servizio collega 5 socket
 *      (stdin, stdout, stderr, controllo, interop; un sesto per l'OOBE); il comando gira con stdin/stdout/stderr sui
 *      socket, a fine corsa lo stato d'uscita va sul canale interop (ExitStatus, che wsl.exe rimanda indietro).
 *
 * Ogni messaggio ricevuto viene descritto su stderr (che rc manda sulla console).
 * Formato dei messaggi: MESSAGE_HEADER {tipo, dimensione, TransactionId, TransactionStep}; i messaggi fuori
 * transazione hanno step 0 e id = contatore per canale e per direzione che parte da 1; la risposta a una richiesta
 * (step 1) porta lo stesso id e step 2 (SocketChannel.h). Le stringhe sono indicate da offset dall'inizio del
 * messaggio; gli elenchi di stringhe sono coppie {int32 lunghezza, byte} chiuse da -1 (message.h, WriteStringArray).
 */
#include <sys/types.h>
#include <sys/event.h>
#include <sys/file.h>
#include <sys/ioctl.h>
#include <sys/procctl.h>
#include <sys/mount.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/utsname.h>
#include <sys/wait.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <ctype.h>
#include <ifaddrs.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <libutil.h>
#include <limits.h>
#include <poll.h>
#include <grp.h>
#include <pwd.h>
#include <signal.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
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
#define WSL_INVALID_PORT	UINT_MAX

/* valori di LX_MESSAGE_TYPE (src/shared/inc/lxinitshared.h, b6fea0ff): posizione nell'enum */
#define MSG_CREATE_SESSION		2
#define MSG_CREATE_SESSION_RESPONSE	3
#define MSG_INITIALIZE			5
#define MSG_INITIALIZE_RESPONSE		6
#define MSG_TIMEZONE_INFORMATION	7
#define MSG_CREATE_PROCESS_UVM		8
#define MSG_EXIT_STATUS			9
#define MSG_WINDOW_SIZE_CHANGED		10
#define MSG_TERMINATE_INSTANCE		14
#define MSG_LAUNCH_INIT			29
#define MSG_IMPORT_INPLACE		31
#define MSG_CREATE_INSTANCE_RESULT	33
#define MSG_IMPORT_RESULT		34
#define MSG_EJECT_VHD			35
#define MSG_EARLY_CONFIG		36
#define MSG_INITIAL_CONFIG		37
#define MSG_GUEST_CAPABILITIES		43
#define MSG_CHILD_EXIT			45
#define MSG_GNS_INTERFACE_CONFIGURATION	53
#define MSG_GNS_RESULT			54
#define MSG_GNS_NOTIFICATION		55
#define MSG_GNS_CONNECT_TEST_REQUEST	74
#define MSG_START_SOCKET_RELAY		15
#define MSG_GNS_SET_PORT_LISTENER	58
#define MSG_GNS_PORT_RELAY_START	59
#define MSG_GNS_PORT_RELAY_STOP		60
#define LX_AF_INET			2	/* famiglie come le vede il servizio: valori di Linux */
#define LX_AF_INET6			10
#define MSG_RESULT_BOOL			76
#define MSG_RESULT_INT32		77
#define MSG_RESULT_UINT32		78

#define LAUNCH_FLAG_READ_ONLY		0x1	/* LxMiniInitMessageFlagMountReadOnly */
#define LAUNCH_FLAG_SYSTEM_DISTRO	0x4	/* LxMiniInitMessageFlagLaunchSystemDistro */
#define PROCESS_FLAGS_CONSOLE		0x7	/* LxInitCreateProcessFlagsStd{In,Out,Err}Console: bit i = fd i */
#define PROCESS_FLAG_ALLOW_OOBE		0x20	/* LxInitCreateProcessFlagAllowOOBE */
#define SHELL_OPTIONS_LOGIN		0x1	/* ShellOptionsLogin */
#define PROCESS_SOCKETS			5	/* LX_INIT_UTILITY_VM_CREATE_PROCESS_SOCKET_COUNT */
#define DISTRO_PATH			"/distro"	/* qui si monta il disco della distro FreeBSD */
#define RESOLV_CONF			"/var/run/claude-wslinit-resolv.conf"	/* DNS dal servizio, copiato nella distro */

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

/* LX_MINI_INIT_MESSAGE (LaunchInit) */
struct launch_init {
	struct msg_header h;
	uint32_t mount_device_type;
	uint32_t device_id;
	uint32_t fs_type_offset;
	uint32_t mount_options_offset;
	uint32_t vm_id_offset;
	uint32_t distribution_name_offset;
	uint32_t shared_memory_root_offset;
	uint32_t install_path_offset;
	uint32_t user_profile_offset;
	uint32_t flags;
	uint32_t connect_port;
	uint8_t instance_id[16];
	char buffer[];
};
_Static_assert(offsetof(struct launch_init, instance_id) == 60, "LX_MINI_INIT_MESSAGE");

struct create_instance_result {
	struct msg_header h;
	int32_t result;
	uint32_t failure_step;
	uint64_t pid;
	uint32_t connect_port;
	uint32_t warnings_offset;
};
_Static_assert(sizeof(struct create_instance_result) == 40, "LX_MINI_INIT_CREATE_INSTANCE_RESULT");

/* LX_MINI_INIT_IMPORT_RESULT */
struct import_result {
	struct msg_header h;
	int32_t result;
	bool valid_distribution;
	uint32_t flavor_index;
	uint32_t version_index;
	uint32_t shortcut_icon_index;
	uint32_t shortcut_icon_size;
	uint32_t default_name_index;
	uint32_t terminal_profile_index;
	uint32_t terminal_profile_size;
	bool generate_terminal_profile;
	bool generate_shortcut;
	char buffer[];
};
_Static_assert(offsetof(struct import_result, generate_terminal_profile) == 52, "LX_MINI_INIT_IMPORT_RESULT");

/* LX_INIT_CONFIGURATION_INFORMATION */
struct init_configuration {
	struct msg_header h;
	uint32_t hostname_offset;
	uint32_t domainname_offset;
	uint32_t windows_hosts_offset;
	uint32_t distribution_name_offset;
	uint32_t plan9_socket_offset;
	uint32_t timezone_offset;
	uint32_t drvfs_volumes_bitmap;
	uint32_t drvfs_default_owner;
	uint32_t feature_flags;
	uint32_t drvfs_mount;
	char buffer[];
};

struct init_configuration_response {
	struct msg_header h;
	uint32_t plan9_port;
	uint32_t default_uid;
	uint32_t interop_port;
	bool systemd_enabled;
	uint64_t pid_namespace;
	uint32_t flavor_index;
	uint32_t version_index;
	char buffer[];
};
_Static_assert(offsetof(struct init_configuration_response, pid_namespace) == 32, "INITIALIZE_RESPONSE");
_Static_assert(offsetof(struct init_configuration_response, buffer) == 48, "INITIALIZE_RESPONSE");

struct create_session_response {
	struct msg_header h;
	uint32_t port;
};

struct result_uint32 {
	struct msg_header h;
	uint32_t result;
};

struct result_int32 {
	struct msg_header h;
	int32_t result;
};

struct result_bool {
	struct msg_header h;
	bool result;
};
_Static_assert(sizeof(struct result_bool) == 20, "RESULT_MESSAGE<bool>");

/* LX_INIT_CREATE_PROCESS_UTILITY_VM */
struct create_process {
	struct msg_header h;
	uint32_t filename_offset;
	uint32_t cwd_offset;
	uint32_t command_line_offset;
	uint32_t environment_offset;
	uint32_t nt_environment_offset;
	uint32_t nt_path_offset;
	uint32_t shell_options;
	uint32_t username_offset;
	uint32_t default_uid;
	int32_t flags;
	uint16_t rows;
	uint16_t columns;
	char buffer[];
};
_Static_assert(offsetof(struct create_process, rows) == 56, "LX_INIT_CREATE_PROCESS_UTILITY_VM");

struct window_size_changed {
	struct msg_header h;
	uint16_t rows;
	uint16_t columns;
};

struct exit_status {
	struct msg_header h;
	int32_t exit_code;
};

/* un canale: il socket, il contatore dei messaggi fuori transazione mandati, quello delle transazioni avviate */
struct chan {
	int fd;
	uint32_t sent;
	const char *name;
	uint32_t tx;
};

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

/*
 * Porta in ascolto per le connessioni del servizio. Il bind di hv_sock non sceglie la porta da se' (HVADDR_PORT_ANY
 * verrebbe preso alla lettera): si prova una porta dopo l'altra, partendo da un punto che dipende dal pid perche'
 * piu' processi (istanza, sessioni) ascoltano insieme.
 */
static int
listen_any(uint32_t *port, int backlog)
{
	static uint32_t next;
	struct sockaddr_hvs sa;
	int fd, tries;

	if (next == 0)
		next = 60000 + (uint32_t)(getpid() % 500) * 64;
	for (tries = 0; tries < 1000; tries++) {
		fd = socket(AF_HYPERV, SOCK_STREAM, 0);
		if (fd < 0)
			err(1, "socket(AF_HYPERV)");
		memset(&sa, 0, sizeof(sa));
		sa.sa_len = sizeof(sa);
		sa.sa_family = AF_HYPERV;
		sa.hvs_port = next++;
		if (bind(fd, (struct sockaddr *)&sa, sizeof(sa)) == 0) {
			if (listen(fd, backlog) < 0)
				err(1, "listen(porta %u)", sa.hvs_port);
			*port = sa.hvs_port;
			return (fd);
		}
		if (errno != EADDRINUSE)
			err(1, "bind(porta %u)", sa.hvs_port);
		close(fd);
	}
	errx(1, "nessuna porta libera per l'ascolto");
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

/* manda un messaggio: fuori transazione (req NULL) o come risposta alla richiesta req */
static void
chan_send(struct chan *c, void *m, uint32_t size, const struct msg_header *req)
{
	struct msg_header *h = m;

	h->size = size;
	if (req != NULL) {
		h->transaction_id = req->transaction_id;
		h->transaction_step = req->transaction_step + 1;
	} else {
		h->transaction_id = ++c->sent;
		h->transaction_step = 0;
	}
	write_all(c->fd, m, size);
}

/* riceve un messaggio intero (da liberare con free); NULL se il canale e' chiuso */
static char *
chan_recv(struct chan *c)
{
	struct msg_header h;
	char *msg;

	if (!read_all(c->fd, &h, sizeof(h)))
		return (NULL);
	if (h.size < sizeof(h) || h.size > 16 * 1024 * 1024)
		errx(1, "%s: dimensione di messaggio non valida %u", c->name, h.size);
	msg = malloc(h.size + 1);
	if (msg == NULL)
		err(1, "malloc");
	memcpy(msg, &h, sizeof(h));
	if (!read_all(c->fd, msg + sizeof(h), h.size - sizeof(h)))
		errx(1, "%s: canale chiuso a meta' messaggio", c->name);
	msg[h.size] = '\0';		/* le stringhe in coda restano comunque terminate */
	warnx("%s: messaggio tipo %u, %u byte, transazione %u passo %u", c->name, h.type, h.size,
	    h.transaction_id, h.transaction_step);
	return (msg);
}

/* stringa a un offset del messaggio; "" se l'offset e' assente o fuori dal messaggio */
static const char *
msg_str(const char *msg, uint32_t off)
{
	const struct msg_header *h = (const struct msg_header *)msg;

	if (off == 0 || off >= h->size)
		return ("");
	return (msg + off);
}

/* elenco di stringhe {int32 lunghezza, byte}... -1 a un offset: vettore terminato da NULL */
static char **
msg_strarray(const char *msg, uint32_t off, int *countp)
{
	const struct msg_header *h = (const struct msg_header *)msg;
	char **v;
	int32_t len;
	uint32_t p;
	int n;

	v = calloc(1, sizeof(*v));
	if (v == NULL)
		err(1, "calloc");
	n = 0;
	for (p = off; off != 0 && p + sizeof(len) <= h->size; ) {
		memcpy(&len, msg + p, sizeof(len));
		p += sizeof(len);
		if (len < 0 || p + (uint32_t)len > h->size)
			break;
		v = realloc(v, (n + 2) * sizeof(*v));
		if (v == NULL)
			err(1, "realloc");
		v[n] = strndup(msg + p, (size_t)len);
		v[++n] = NULL;
		p += (uint32_t)len;
	}
	if (countp != NULL)
		*countp = n;
	return (v);
}

/* versione di FreeBSD: "15.2-PRERELEASE" -> "15.2" */
static void
os_version(char *buf, size_t len)
{
	struct utsname u;

	if (uname(&u) < 0)
		err(1, "uname");
	snprintf(buf, len, "%.*s", (int)strcspn(u.release, "-"), u.release);
}

static void
send_capabilities(struct chan *c)
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
	m->seccomp_available = false;
	m->ipv6_available = true;
	memcpy(m->buffer, rel, len);
	chan_send(c, m, (uint32_t)size, NULL);
	warnx("GuestCapabilities mandato (kernel %s, %zu byte)", rel, size);
	free(m);
}

/*
 * /etc/wsl.conf della distro (formato INI, come in WslDistributionConfig.cpp): "[sezione]" poi "chiave = valore";
 * commenti con # o ;. Chiavi usate: user.default, network.generateResolvConf, network.hostname,
 * time.useWindowsTimezone, boot.command. root e' la radice della distro vista da chi chiama ("/distro" o "/").
 */
static bool
wslconf_get(const char *root, const char *section, const char *key, char *val, size_t len)
{
	char path[128], line[1024], cur[64] = "";
	char *p, *e, *eq;
	FILE *f;
	bool found = false;

	snprintf(path, sizeof(path), "%s/etc/wsl.conf", root);
	if ((f = fopen(path, "r")) == NULL)
		return (false);
	while (fgets(line, sizeof(line), f) != NULL) {
		for (p = line; isspace((unsigned char)*p); p++)
			;
		if (*p == '#' || *p == ';' || *p == '\0')
			continue;
		for (e = p + strlen(p); e > p && isspace((unsigned char)e[-1]); )
			*--e = '\0';
		if (*p == '[') {
			snprintf(cur, sizeof(cur), "%.*s", (int)strcspn(p + 1, "]"), p + 1);
			continue;
		}
		if (strcasecmp(cur, section) != 0 || (eq = strchr(p, '=')) == NULL)
			continue;
		for (e = eq; e > p && isspace((unsigned char)e[-1]); e--)
			;
		if ((size_t)(e - p) != strlen(key) || strncasecmp(p, key, strlen(key)) != 0)
			continue;
		for (p = eq + 1; isspace((unsigned char)*p); p++)
			;
		if (*p == '"' && (e = strrchr(p + 1, '"')) != NULL) {
			p++;
			*e = '\0';
		}
		snprintf(val, len, "%s", p);
		found = true;
	}
	fclose(f);
	return (found);
}

/* un valore booleano di wsl.conf, def se assente */
static bool
wslconf_bool(const char *root, const char *section, const char *key, bool def)
{
	char v[16];

	if (!wslconf_get(root, section, key, v, sizeof(v)))
		return (def);
	return (strcasecmp(v, "true") == 0 || strcmp(v, "1") == 0 || strcasecmp(v, "yes") == 0);
}

/* uid di un utente nel passwd della distro (letto come file: l'istanza non e' in chroot); -1 se non c'e' */
static long
distro_uid(const char *name)
{
	char line[1024], *f[4], *p;
	long uid = -1;
	FILE *fp;
	int n;

	if ((fp = fopen(DISTRO_PATH "/etc/passwd", "r")) == NULL)
		return (-1);
	while (uid < 0 && fgets(line, sizeof(line), fp) != NULL) {
		for (n = 0, p = line; n < 4 && (f[n] = strsep(&p, ":")) != NULL; n++)
			;
		if (n == 4 && strcmp(f[0], name) == 0)
			uid = strtol(f[2], NULL, 10);
	}
	fclose(fp);
	return (uid);
}

/* fuso orario di Windows nella distro: /etc/localtime -> /usr/share/zoneinfo/<zona> (se time.useWindowsTimezone) */
static void
apply_timezone(const char *tz)
{
	char zone[256];

	if (*tz == '\0' || strstr(tz, "..") != NULL || !wslconf_bool(DISTRO_PATH, "time", "useWindowsTimezone", true))
		return;
	snprintf(zone, sizeof(zone), DISTRO_PATH "/usr/share/zoneinfo/%s", tz);
	if (access(zone, R_OK) < 0) {
		warnx("fuso: zona '%s' assente nella distro", tz);
		return;
	}
	/* il collegamento e' relativo alla radice della distro, come lo vedono i suoi processi */
	snprintf(zone, sizeof(zone), "/usr/share/zoneinfo/%s", tz);
	(void)unlink(DISTRO_PATH "/etc/localtime");
	if (symlink(zone, DISTRO_PATH "/etc/localtime") < 0)
		warn("fuso: symlink");
	else
		warnx("fuso: /etc/localtime -> %s", zone);
}

/*
 * Il processo del comando: stdin/stdout/stderr sui socket, ambiente dal servizio con PATH/HOME di FreeBSD.
 * Nome vuoto = shell (come init.cpp: argv[0] "-sh" se e' chiesta la shell di login), altrimenti execvp del nome
 * con la riga di comando cosi' com'e'.
 */
static void
exec_command(const char *msg, int fds[])
{
	const struct create_process *cp = (const struct create_process *)msg;
	const char *filename, *cwd, *shell, *base, *username;
	struct passwd *pw;
	char **argv, **env, **full;
	char login[64];
	int argc, envc, i;

	for (i = 0; i < 3; i++)
		if (dup2(fds[i], i) < 0)
			err(1, "dup2");
	for (i = 3; i < 64; i++)
		close(i);
	setsid();
	/* il comando vede come radice la distro FreeBSD dell'utente (l'istanza resta fuori, per smontarla alla fine) */
	if (chroot(DISTRO_PATH) < 0 || chdir("/") < 0)
		err(126, "chroot(%s)", DISTRO_PATH);
	/* il terminale (se c'e') diventa quello di controllo: ^C, job control, stty */
	for (i = 0; i < 3; i++)
		if ((cp->flags & (1 << i)) != 0) {
			if (ioctl(i, TIOCSCTTY, 0) < 0)
				warn("TIOCSCTTY");
			break;
		}

	filename = msg_str(msg, cp->filename_offset);
	cwd = msg_str(msg, cp->cwd_offset);
	argv = msg_strarray(msg, cp->command_line_offset, &argc);
	env = msg_strarray(msg, cp->environment_offset, &envc);

	/*
	 * L'utente: quello chiesto (wsl -u <nome>), altrimenti l'uid predefinito che il servizio rimanda (quello della
	 * nostra risposta a Initialize: user.default di wsl.conf, o il valore registrato). Dal passwd della distro.
	 */
	username = msg_str(msg, cp->username_offset);
	pw = *username != '\0' ? getpwnam(username) : getpwuid((uid_t)cp->default_uid);
	if (pw == NULL) {
		warnx("utente '%s' (uid %u) assente nella distro: root", username, cp->default_uid);
		pw = getpwuid(0);
	}
	if (pw == NULL)
		errx(126, "nessun utente root nella distro");
	for (i = 0; i < 3; i++)
		if ((cp->flags & (1 << i)) != 0) {
			/* il terminale appartiene all'utente (gruppo tty), come fa login */
			struct group *tty = getgrnam("tty");

			(void)fchown(i, pw->pw_uid, tty != NULL ? tty->gr_gid : (gid_t)-1);
			(void)fchmod(i, 0620);
			break;
		}
	if (initgroups(pw->pw_name, pw->pw_gid) < 0 || setgid(pw->pw_gid) < 0 || setuid(pw->pw_uid) < 0)
		err(126, "utente %s", pw->pw_name);

	clearenv();
	for (i = 0; i < envc; i++)
		putenv(env[i]);
	setenv("PATH", pw->pw_uid == 0 ? "/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin" :
	    "/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin", 1);
	setenv("HOME", pw->pw_dir, 1);
	setenv("USER", pw->pw_name, 1);
	setenv("LOGNAME", pw->pw_name, 1);
	shell = (pw->pw_shell != NULL && *pw->pw_shell != '\0') ? pw->pw_shell : "/bin/sh";
	setenv("SHELL", shell, 1);

	/* la cartella di Windows (C:\...) non esiste qui: la home dell'utente */
	if (*cwd == '\0' || *cwd == '~' || chdir(cwd) < 0)
		if (chdir(pw->pw_dir) < 0)
			(void)chdir("/");

	if (*filename == '\0') {
		/* la shell dell'utente dal passwd della distro; "-sh" come argv[0] per la shell di login */
		base = strrchr(shell, '/') != NULL ? strrchr(shell, '/') + 1 : shell;
		snprintf(login, sizeof(login), "-%s", base);
		full = calloc((size_t)argc + 2, sizeof(*full));
		if (full == NULL)
			err(1, "calloc");
		full[0] = (cp->shell_options & SHELL_OPTIONS_LOGIN) ? login : (char *)shell;
		for (i = 0; i < argc; i++)
			full[i + 1] = argv[i];
		execv(shell, full);
		err(127, "execv(%s)", shell);
	}
	if (argc == 0) {
		argv = realloc(argv, 2 * sizeof(*argv));
		argv[0] = strdup(filename);
		argv[1] = NULL;
	}
	execvp(filename, argv);
	err(127, "execvp(%s)", filename);
}

/* scrive tutto; false se l'altra parte ha chiuso */
static bool
write_some(int fd, const char *p, ssize_t n)
{
	ssize_t w;

	while (n > 0) {
		w = write(fd, p, (size_t)n);
		if (w < 0) {
			if (errno == EINTR)
				continue;
			return (false);
		}
		p += w;
		n -= w;
	}
	return (true);
}

/*
 * Il ponte del terminale (come init.cpp con le console di Windows): i fd che wsl.exe dichiara console finiscono su un
 * pty; il socket stdin alimenta il master, l'uscita del master va al socket stdout (o stderr), il canale di controllo
 * porta i cambi di dimensione (TIOCSWINSZ).
 * I socket hvsock NON si guardano con kqueue: in hv_sock i dati stanno nell'anello VMBus e non nel sockbuf, e
 * EVFILT_READ scattava senza dati, lasciando il ponte fermo in read() per sempre (prova del 03/11 18:03: comando
 * finito e mai raccolto). Stdin e controllo hanno quindi un processo ciascuno, con letture bloccanti; qui si guardano
 * solo il master (un pty: kqueue affidabile) e la fine del comando.
 */
static int
relay_pty(const char *msg, int sockets[], int master, pid_t child)
{
	const struct create_process *cp = (const struct create_process *)msg;
	struct kevent ev[2], got;
	struct winsize ws;
	char buf[4096];
	ssize_t n;
	pid_t in_pid = -1, ctl_pid;
	int kq, out, status = 0;

	out = (cp->flags & 0x2) ? sockets[1] : (cp->flags & 0x4) ? sockets[2] : -1;
	if ((cp->flags & 0x1) != 0) {
		in_pid = fork();
		if (in_pid == 0) {
			while ((n = read(sockets[0], buf, sizeof(buf))) > 0)
				if (!write_some(master, buf, n))
					break;
			_exit(0);
		}
	}
	ctl_pid = fork();
	if (ctl_pid == 0) {
		struct chan tctl = { sockets[3], 0, "terminale", 0 };
		char *m;

		while ((m = chan_recv(&tctl)) != NULL) {
			if (((struct msg_header *)m)->type == MSG_WINDOW_SIZE_CHANGED) {
				const struct window_size_changed *w = (const struct window_size_changed *)m;

				memset(&ws, 0, sizeof(ws));
				ws.ws_row = w->rows;
				ws.ws_col = w->columns;
				(void)ioctl(master, TIOCSWINSZ, &ws);
			}
			free(m);
		}
		_exit(0);
	}

	kq = kqueue();
	if (kq < 0)
		err(1, "kqueue");
	EV_SET(&ev[0], master, EVFILT_READ, EV_ADD, 0, 0, NULL);
	EV_SET(&ev[1], child, EVFILT_PROC, EV_ADD | EV_ONESHOT, NOTE_EXIT, 0, NULL);
	if (kevent(kq, ev, 2, NULL, 0, NULL) < 0)
		err(1, "kevent");
	fcntl(master, F_SETFL, fcntl(master, F_GETFL) | O_NONBLOCK);
	for (;;) {
		if (kevent(kq, NULL, 0, &got, 1, NULL) < 0) {
			if (errno == EINTR)
				continue;
			err(1, "kevent");
		}
		if (got.filter == EVFILT_PROC) {
			while (waitpid(child, &status, 0) < 0 && errno == EINTR)
				;
			/* svuota quel che resta sul master */
			while ((n = read(master, buf, sizeof(buf))) > 0)
				if (out >= 0)
					(void)write_some(out, buf, n);
			break;
		}
		n = read(master, buf, sizeof(buf));
		if (n > 0) {
			if (out >= 0)
				(void)write_some(out, buf, n);
		} else if (n == 0 || errno != EAGAIN) {
			/* nessuno tiene piu' aperto lo slave: resta solo da aspettare la fine del comando */
			EV_SET(&ev[0], master, EVFILT_READ, EV_DELETE, 0, 0, NULL);
			(void)kevent(kq, ev, 1, NULL, 0, NULL);
		}
	}
	close(kq);
	if (in_pid > 0)
		kill(in_pid, SIGKILL);
	kill(ctl_pid, SIGKILL);
	if (in_pid > 0)
		(void)waitpid(in_pid, NULL, 0);
	(void)waitpid(ctl_pid, NULL, 0);
	return (status);
}

/* CreateProcessUtilityVm sul canale della sessione */
static void
create_process(struct chan *c, const char *msg)
{
	const struct create_process *cp = (const struct create_process *)msg;
	struct result_uint32 r;
	struct exit_status es;
	struct chan ctl;
	char **argv;
	char *m;
	int sockets[PROCESS_SOCKETS + 1];
	struct winsize ws;
	int fds[3];
	int argc, i, lfd, nsock, status, master, slave;
	pid_t relay, child;
	uint32_t port;

	argv = msg_strarray(msg, cp->command_line_offset, &argc);
	warnx("CreateProcess: nome '%s', %d argomenti%s%s, cwd '%s', utente '%s', uid %u, flag 0x%x, %ux%u",
	    msg_str(msg, cp->filename_offset), argc, argc > 0 ? ", argv[0] " : "", argc > 0 ? argv[0] : "",
	    msg_str(msg, cp->cwd_offset), msg_str(msg, cp->username_offset), cp->default_uid, cp->flags,
	    cp->columns, cp->rows);

	nsock = PROCESS_SOCKETS + ((cp->flags & PROCESS_FLAG_ALLOW_OOBE) ? 1 : 0);
	lfd = listen_any(&port, nsock);
	memset(&r, 0, sizeof(r));
	r.h.type = MSG_RESULT_UINT32;
	r.result = port;
	chan_send(c, &r, sizeof(r), &cp->h);
	for (i = 0; i < nsock; i++) {
		sockets[i] = accept(lfd, NULL, NULL);
		if (sockets[i] < 0)
			err(1, "accept (socket %d del processo)", i);
	}
	close(lfd);
	warnx("CreateProcess: %d socket collegati sulla porta %u", nsock, port);

	relay = fork();
	if (relay < 0)
		err(1, "fork");
	if (relay > 0) {
		for (i = 0; i < nsock; i++)
			close(sockets[i]);
		return;
	}

	/* il processo di appoggio: lancia il comando, ne aspetta la fine, manda lo stato d'uscita */
	close(c->fd);
	signal(SIGCHLD, SIG_DFL);
	master = slave = -1;
	if ((cp->flags & PROCESS_FLAGS_CONSOLE) != 0) {
		memset(&ws, 0, sizeof(ws));
		ws.ws_row = cp->rows;
		ws.ws_col = cp->columns;
		if (openpty(&master, &slave, NULL, NULL, &ws) < 0)
			err(1, "openpty");
		warnx("CreateProcess: terminale %s (%ux%u) per i fd console 0x%x", ttyname(slave), cp->columns, cp->rows,
		    cp->flags & PROCESS_FLAGS_CONSOLE);
	}
	for (i = 0; i < 3; i++)
		fds[i] = (cp->flags & (1 << i)) != 0 ? slave : sockets[i];
	child = fork();
	if (child < 0)
		err(1, "fork");
	if (child == 0)
		exec_command(msg, fds);
	if (master >= 0) {
		close(slave);
		/* i socket dei fd non console li tiene solo il comando */
		for (i = 0; i < 3; i++)
			if ((cp->flags & (1 << i)) == 0)
				close(sockets[i]);
		status = relay_pty(msg, sockets, master, child);
		close(master);
		for (i = 0; i < 3; i++)
			if ((cp->flags & (1 << i)) != 0)
				close(sockets[i]);
	} else {
		for (i = 0; i < 3; i++)
			close(sockets[i]);
		while (waitpid(child, &status, 0) < 0)
			if (errno != EINTR)
				err(1, "waitpid");
	}
	memset(&es, 0, sizeof(es));
	es.h.type = MSG_EXIT_STATUS;
	es.exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
	warnx("CreateProcess: pid %d finito, codice %d", child, es.exit_code);
	/*
	 * Lo stato d'uscita va sul quinto socket (interop): e' li' che wsl.exe lo aspetta (VmModeWorkerThread,
	 * svccomm.cpp) e lo rimanda indietro come conferma. Il quarto (controllo del terminale) porta solo i cambi di
	 * dimensione della finestra.
	 */
	ctl = (struct chan){ sockets[4], 0, "interop", 0 };
	chan_send(&ctl, &es, sizeof(es), NULL);
	while ((m = chan_recv(&ctl)) != NULL) {
		uint32_t type = ((struct msg_header *)m)->type;

		free(m);
		if (type == MSG_EXIT_STATUS)
			break;
	}
	_exit(0);
}

/* il capo sessione: riceve le richieste di processo della sessione */
static void
session_leader(int fd)
{
	struct chan c = { fd, 0, "sessione", 0 };
	char *m;

	warnx("sessione: capo sessione pid %d", getpid());
	while ((m = chan_recv(&c)) != NULL) {
		switch (((struct msg_header *)m)->type) {
		case MSG_CREATE_PROCESS_UVM:
			create_process(&c, m);
			break;
		default:
			warnx("sessione: tipo %u non gestito", ((struct msg_header *)m)->type);
			break;
		}
		free(m);
	}
	warnx("sessione: il servizio ha chiuso il canale");
	_exit(0);
}

static void
initialize_instance(struct chan *c, const char *msg)
{
	const struct init_configuration *ic = (const struct init_configuration *)msg;
	struct init_configuration_response *r;
	const char *hostname;
	char version[64], name[MAXHOSTNAMELEN], cmd[1024];
	const char flavor[] = "freebsd";
	uint32_t default_uid;
	size_t size;

	hostname = msg_str(msg, ic->hostname_offset);
	warnx("Initialize: distro '%s', hostname '%s', dominio '%s', fuso '%s', funzioni 0x%x, proprietario drvfs %u",
	    msg_str(msg, ic->distribution_name_offset), hostname, msg_str(msg, ic->domainname_offset),
	    msg_str(msg, ic->timezone_offset), ic->feature_flags, ic->drvfs_default_owner);
	if (wslconf_get(DISTRO_PATH, "network", "hostname", name, sizeof(name)))
		hostname = name;
	if (*hostname != '\0' && sethostname(hostname, (int)strlen(hostname)) < 0)
		warn("sethostname");
	apply_timezone(msg_str(msg, ic->timezone_offset));

	/* utente predefinito: user.default di wsl.conf, altrimenti quello registrato nel servizio */
	default_uid = ic->drvfs_default_owner;
	if (wslconf_get(DISTRO_PATH, "user", "default", name, sizeof(name))) {
		long uid = distro_uid(name);

		if (uid >= 0)
			default_uid = (uint32_t)uid;
		else
			warnx("Initialize: user.default '%s' assente nel passwd della distro", name);
	}

	/* boot.command: come root, staccato, nella distro (lo chiude TerminateInstance insieme al resto) */
	if (wslconf_get(DISTRO_PATH, "boot", "command", cmd, sizeof(cmd)) && fork() == 0) {
		int nul = open("/dev/null", O_RDWR);

		setsid();
		if (chroot(DISTRO_PATH) < 0 || chdir("/") < 0)
			_exit(126);
		dup2(nul, 0);
		dup2(nul, 1);
		dup2(nul, 2);
		execl("/bin/sh", "sh", "-c", cmd, (char *)NULL);
		_exit(127);
	}

	os_version(version, sizeof(version));
	size = sizeof(*r) + sizeof(flavor) + strlen(version) + 1;
	r = calloc(1, size);
	if (r == NULL)
		err(1, "calloc");
	r->h.type = MSG_INITIALIZE_RESPONSE;
	r->plan9_port = WSL_INVALID_PORT;
	r->default_uid = default_uid;
	r->interop_port = WSL_INVALID_PORT;
	r->systemd_enabled = false;
	r->pid_namespace = 0;
	r->flavor_index = (uint32_t)sizeof(*r);
	memcpy(r->buffer, flavor, sizeof(flavor));
	r->version_index = (uint32_t)(sizeof(*r) + sizeof(flavor));
	memcpy(r->buffer + sizeof(flavor), version, strlen(version) + 1);
	chan_send(c, r, (uint32_t)size, &ic->h);
	warnx("Initialize: risposto (uid predefinito %u, %s %s)", default_uid, flavor, version);
	free(r);
}

static void
create_session(struct chan *c, const char *msg)
{
	struct create_session_response r;
	pid_t pid;
	uint32_t port;
	int lfd, fd;

	lfd = listen_any(&port, 1);
	memset(&r, 0, sizeof(r));
	r.h.type = MSG_CREATE_SESSION_RESPONSE;
	r.port = port;
	chan_send(c, &r, sizeof(r), (const struct msg_header *)msg);
	fd = accept(lfd, NULL, NULL);
	if (fd < 0)
		err(1, "accept (sessione)");
	close(lfd);
	warnx("CreateSession: sessione collegata sulla porta %u", port);
	pid = fork();
	if (pid < 0)
		err(1, "fork");
	if (pid == 0) {
		close(c->fd);
		session_leader(fd);
	}
	close(fd);
}

static int run_out(const char *const argv[], char *out, size_t outlen, int timeout_s);

/* esegue un programma e ne aspetta la fine (al massimo 120 s); il codice d'uscita, -1 se non e' partito o e' morto */
static int
run(const char *const argv[])
{
	return (run_out(argv, NULL, 0, 120));
}

/*
 * Esegue un programma; con out != NULL ne raccoglie lo stdout (troncato a outlen), altrimenti lo stdout va dove va il
 * nostro (la console). Se non finisce entro timeout_s secondi: procstat -kk del processo sulla console (DOVE e'
 * bloccato), poi SIGKILL. Prova del 03/11 17:46: l'istanza ferma in silenzio dentro camcontrol o gpart.
 * SIGCHLD torna SIG_DFL per la durata dell'attesa: con SIG_IGN (ereditato da main) il figlio verrebbe raccolto da
 * solo e waitpid darebbe ECHILD (prova del 03/11 17:16: fsck e mount riusciti ma riportati come -1).
 */
static int
run_out(const char *const argv[], char *out, size_t outlen, int timeout_s)
{
	void (*prev)(int);
	struct pollfd pfd;
	char buf[512], spid[16];
	size_t used = 0;
	ssize_t n;
	struct timespec t0, now;
	pid_t pid, w;
	int p[2], status, rc = -1;
	bool eof = false, killed = false;

	if (out != NULL && outlen > 0)
		out[0] = '\0';
	if (pipe(p) < 0)
		return (-1);
	prev = signal(SIGCHLD, SIG_DFL);
	pid = fork();
	if (pid < 0) {
		close(p[0]);
		close(p[1]);
		signal(SIGCHLD, prev);
		return (-1);
	}
	if (pid == 0) {
		close(p[0]);
		if (out != NULL)
			dup2(p[1], STDOUT_FILENO);
		close(p[1]);
		execv(argv[0], (char *const *)argv);
		_exit(127);
	}
	close(p[1]);
	clock_gettime(CLOCK_MONOTONIC, &t0);
	for (;;) {
		if (!eof) {
			pfd.fd = p[0];
			pfd.events = POLLIN;
			if (poll(&pfd, 1, 200) > 0) {
				n = read(p[0], buf, sizeof(buf));
				if (n <= 0)
					eof = true;
				else if (out != NULL && used + 1 < outlen) {
					size_t k = MIN((size_t)n, outlen - 1 - used);

					memcpy(out + used, buf, k);
					used += k;
					out[used] = '\0';
				}
			}
		} else
			usleep(100000);
		w = waitpid(pid, &status, WNOHANG);
		if (w == pid) {
			rc = WIFEXITED(status) ? WEXITSTATUS(status) : -1;
			break;
		}
		if (w < 0 && errno != EINTR)
			break;
		/*
		 * Orologio MONOTONO: all'avvio la sincronizzazione dell'ora di Hyper-V sposta il tempo di sistema
		 * (prova del 03/11 18:03: con time() il limite non scattava mai).
		 */
		clock_gettime(CLOCK_MONOTONIC, &now);
		if (!killed && now.tv_sec - t0.tv_sec >= timeout_s) {
			warnx("%s: BLOCCATO da %d s (pid %d), pila nel kernel:", argv[0], timeout_s, pid);
			snprintf(spid, sizeof(spid), "%d", pid);
			(void)run_out((const char *const[]){ "/usr/bin/procstat", "-kk", spid, NULL }, NULL, 0, 20);
			kill(pid, SIGKILL);
			killed = true;
		}
	}
	close(p[0]);
	signal(SIGCHLD, prev);
	return (rc);
}

/*
 * Il disco SCSI al lun indicato dal servizio: "<Msft Virtual Disk 1.0> at scbus0 target 0 lun 2 (pass2,da2)" in
 * camcontrol devlist. Il servizio collega il VHD a caldo subito prima del messaggio: si aspetta fino a 30 s.
 */
static bool
lun_device(uint32_t lun, char *dev, size_t len)
{
	char out[4096], key[32];
	char *line, *rest, *p, *q;
	int tries;

	snprintf(key, sizeof(key), " lun %u (", lun);
	for (tries = 0; tries < 60; tries++) {
		(void)run_out((const char *const[]){ "/sbin/camcontrol", "devlist", NULL }, out, sizeof(out), 20);
		for (rest = out; (line = strsep(&rest, "\n")) != NULL; ) {
			if ((p = strstr(line, key)) == NULL)
				continue;
			for (p += strlen(key); (q = strsep(&p, ",)")) != NULL; )
				if (strncmp(q, "da", 2) == 0) {
					snprintf(dev, len, "/dev/%s", q);
					return (true);
				}
		}
		usleep(500000);
	}
	return (false);
}

/*
 * La partizione UFS del disco della distro: la prima di tipo freebsd-ufs in "gpart show -p <disco>"
 * ("  2163891  10486413  da2p4  freebsd-ufs  (5.0G)"). Si legge il TIPO, non si indovina dal suffisso: il disco
 * appena collegato compare prima delle sue partizioni e i nodi arrivano uno alla volta (prova del 03/11 17:38: c'era
 * gia' da2p2, la EFI, e non ancora da2p4). Si aspetta fino a 10 s; un disco senza GPT si usa intero.
 */
static bool
distro_partition(const char *disk, char *part, size_t len)
{
	char out[4096], name[64], type[64];
	char *line, *rest;
	struct stat st;
	int tries;

	for (tries = 0; tries < 20; tries++) {
		(void)run_out((const char *const[]){ "/sbin/gpart", "show", "-p", disk + strlen("/dev/"), NULL }, out,
		    sizeof(out), 20);
		for (rest = out; (line = strsep(&rest, "\n")) != NULL; )
			if (sscanf(line, "%*s %*s %63s %63s", name, type) == 2 && strcmp(type, "freebsd-ufs") == 0) {
				snprintf(part, len, "/dev/%s", name);
				if (stat(part, &st) == 0)
					return (true);
			}
		usleep(500000);
	}
	snprintf(part, len, "%s", disk);
	return (stat(part, &st) == 0);
}

static bool
is_mounted(const char *path)
{
	struct statfs sf;

	return (statfs(path, &sf) == 0 && strcmp(sf.f_mntonname, path) == 0);
}

static int mount_distro_locked(uint32_t lun, bool ro, bool with_devfs);

/*
 * Monta il disco della distro su DISTRO_PATH; 0 o errno. Sotto lucchetto: due istanze (un wsl.exe ancora fermo e uno
 * nuovo) facevano fsck e mount sullo stesso disco insieme (prova del 03/11 18:00: WSL_E_DISK_CORRUPTED).
 */
static int
mount_distro(uint32_t lun, bool ro, bool with_devfs)
{
	int fd, rc;

	fd = open("/var/run/claude-wslinit-distro.lock", O_RDWR | O_CREAT | O_CLOEXEC, 0600);
	if (fd < 0 || flock(fd, LOCK_EX) < 0)
		warn("distro: lucchetto");
	rc = mount_distro_locked(lun, ro, with_devfs);
	if (fd >= 0)
		close(fd);
	return (rc);
}

/* fine dell'istanza: chiude tutti i suoi discendenti, poi smonta devfs e la distro (con sync) */
static void
unmount_distro(const char *what)
{
	struct procctl_reaper_kill rk;
	int rc;

	memset(&rk, 0, sizeof(rk));
	rk.rk_sig = SIGKILL;
	if (procctl(P_PID, getpid(), PROC_REAP_KILL, &rk) < 0)
		warn("%s: PROC_REAP_KILL", what);
	else
		warnx("%s: chiusi %u processi", what, rk.rk_killed);
	usleep(200000);
	sync();
	if (is_mounted(DISTRO_PATH "/dev"))
		(void)run((const char *const[]){ "/sbin/umount", DISTRO_PATH "/dev", NULL });
	rc = is_mounted(DISTRO_PATH) ? run((const char *const[]){ "/sbin/umount", DISTRO_PATH, NULL }) : 0;
	warnx("%s: distro smontata (%d)", what, rc);
}

/* monta il disco della distro su DISTRO_PATH (fsck prima: wsl --shutdown spegne la VM senza smontare); 0 o errno */
static int
mount_distro_locked(uint32_t lun, bool ro, bool with_devfs)
{
	char disk[64], part[80];
	int rc;

	if (is_mounted(DISTRO_PATH)) {
		warnx("distro: %s gia' montato", DISTRO_PATH);
		return (0);
	}
	warnx("distro: cerco il disco al lun %u", lun);
	if (!lun_device(lun, disk, sizeof(disk))) {
		warnx("distro: nessun disco al lun %u", lun);
		return (ENODEV);
	}
	warnx("distro: disco %s, cerco la partizione UFS", disk);
	if (!distro_partition(disk, part, sizeof(part))) {
		warnx("distro: nessuna partizione su %s", disk);
		return (ENODEV);
	}
	rc = run((const char *const[]){ "/sbin/fsck", "-p", "-t", "ufs", part, NULL });
	warnx("distro: fsck -p %s -> %d", part, rc);
	rc = run((const char *const[]){ "/sbin/mount", "-t", "ufs", "-o", ro ? "ro" : "rw", part, DISTRO_PATH, NULL });
	if (rc != 0) {
		warnx("distro: mount %s su %s fallito (%d)", part, DISTRO_PATH, rc);
		return (EIO);
	}
	if (with_devfs && run((const char *const[]){ "/sbin/mount", "-t", "devfs", "devfs", DISTRO_PATH "/dev", NULL }) != 0)
		warnx("distro: devfs su %s/dev non montato", DISTRO_PATH);
	warnx("distro: %s montato su %s (%s)", part, DISTRO_PATH, ro ? "sola lettura" : "lettura e scrittura");
	if (!ro && access(RESOLV_CONF, R_OK) == 0 && wslconf_bool(DISTRO_PATH, "network", "generateResolvConf", true))
		(void)run((const char *const[]){ "/bin/cp", RESOLV_CONF, DISTRO_PATH "/etc/resolv.conf", NULL });
	return (0);
}

/* versione della distro dal suo /bin/freebsd-version (USERLAND_VERSION="15.2-PRERELEASE" -> "15.2") */
static void
distro_version(const char *root, char *buf, size_t len)
{
	char path[128], line[256];
	FILE *f;
	char *p;

	os_version(buf, len);
	snprintf(path, sizeof(path), "%s/bin/freebsd-version", root);
	if ((f = fopen(path, "r")) == NULL)
		return;
	while (fgets(line, sizeof(line), f) != NULL)
		if ((p = strstr(line, "USERLAND_VERSION=\"")) != NULL) {
			p += strlen("USERLAND_VERSION=\"");
			snprintf(buf, len, "%.*s", (int)strcspn(p, "-\""), p);
			break;
		}
	fclose(f);
}

/*
 * wsl --import-in-place: il servizio collega il VHD e chiede di verificarlo (ProcessImportExportMessage in main.cpp):
 * CreateInstanceResult con la porta su cui collega due socket (dati, errori: inutili per l'import sul posto), poi
 * ImportResult. Distro valida = ha /etc e /bin/sh.
 */
static void
import_inplace(int fd, const char *msg)
{
	const struct launch_init *li = (const struct launch_init *)msg;
	struct create_instance_result res;
	struct import_result *ir;
	struct chan c = { fd, 0, "importazione", 0 };
	const char flavor[] = "freebsd";
	char version[64];
	uint32_t port;
	size_t size;
	int lfd, s1, s2, rc;
	bool valid;

	warnx("importazione: distro '%s', disco lun %u", msg_str(msg, li->distribution_name_offset), li->device_id);
	rc = mount_distro(li->device_id, true, false);
	lfd = listen_any(&port, 2);
	memset(&res, 0, sizeof(res));
	res.h.type = MSG_CREATE_INSTANCE_RESULT;
	res.result = rc;
	res.failure_step = 1;		/* LxInitCreateInstanceStepMountDisk */
	res.pid = (uint64_t)getpid();
	res.connect_port = port;
	chan_send(&c, &res, sizeof(res), NULL);
	if (rc != 0)
		_exit(1);
	s1 = accept(lfd, NULL, NULL);
	s2 = accept(lfd, NULL, NULL);
	valid = access(DISTRO_PATH "/etc", F_OK) == 0 && access(DISTRO_PATH "/bin/sh", F_OK) == 0;
	distro_version(DISTRO_PATH, version, sizeof(version));
	sync();
	rc = run((const char *const[]){ "/sbin/umount", DISTRO_PATH, NULL });

	size = sizeof(*ir) + sizeof(flavor) + strlen(version) + 1;
	ir = calloc(1, size);
	if (ir == NULL)
		err(1, "calloc");
	ir->h.type = MSG_IMPORT_RESULT;
	ir->result = rc == 0 ? 0 : -1;
	ir->valid_distribution = valid;
	ir->flavor_index = (uint32_t)sizeof(*ir);
	memcpy(ir->buffer, flavor, sizeof(flavor));
	ir->version_index = (uint32_t)(sizeof(*ir) + sizeof(flavor));
	memcpy(ir->buffer + sizeof(flavor), version, strlen(version) + 1);
	chan_send(&c, ir, (uint32_t)size, NULL);
	warnx("importazione: risultato %d, distro %s, %s %s", ir->result, valid ? "valida" : "NON valida", flavor,
	    version);
	close(s1);
	close(s2);
	_exit(0);
}


/*
 * Rete (modalita' NAT): il motore GNS. Il servizio aggiunge a caldo una scheda di rete Hyper-V (hn in FreeBSD) e sul
 * canale GNS manda, come transazioni, JSON da applicare (GnsEngine.cpp in Linux, NatNetworking.cpp nel servizio):
 *   53 InterfaceConfiguration: l'endpoint HNS {IPAddress, PrefixLength, GatewayAddress, MacAddress, ...};
 *   55 Notification: {AdapterId GUID} + ModifyGuestEndpointSettingRequest {RequestType, ResourceType, Settings}
 *      con ResourceType "Route" {NextHop, DestinationPrefix, Family}, "DNS" {ServerList, Search}, "Interface" {NlMtu};
 *   altri (61-75): niente da fare qui, ConnectTestRequest (74) serve solo alla telemetria.
 * Ogni messaggio vuole in risposta LX_GNS_RESULT {Result}: senza, il servizio resta fermo nella creazione della VM.
 */
struct gns_result {
	struct msg_header h;
	int32_t result;
};

/* il valore di "chiave": stringa (senza virgolette) o numero; false se la chiave non c'e' */
static bool
json_get(const char *json, const char *key, char *val, size_t len)
{
	char pat[64];
	const char *p, *e;

	snprintf(pat, sizeof(pat), "\"%s\":", key);
	if ((p = strstr(json, pat)) == NULL)
		return (false);
	p += strlen(pat);
	while (*p == ' ')
		p++;
	if (*p == '"') {
		p++;
		e = strchr(p, '"');
	} else
		e = p + strcspn(p, ",}] ");
	if (e == NULL)
		return (false);
	snprintf(val, len, "%.*s", (int)(e - p), p);
	return (true);
}

/* l'interfaccia col MAC indicato ("00-15-5D-12-34-56"); la scheda arriva a caldo: si aspetta fino a 15 s */
static bool
iface_by_mac(const char *mac, char *name, size_t len)
{
	struct ifaddrs *ifa, *i;
	struct sockaddr_dl *sdl;
	unsigned int b[6];
	unsigned char want[6];
	int k, tries;

	if (sscanf(mac, "%x%*[-:]%x%*[-:]%x%*[-:]%x%*[-:]%x%*[-:]%x", &b[0], &b[1], &b[2], &b[3], &b[4], &b[5]) != 6)
		return (false);
	for (k = 0; k < 6; k++)
		want[k] = (unsigned char)b[k];
	for (tries = 0; tries < 30; tries++) {
		if (getifaddrs(&ifa) == 0) {
			for (i = ifa; i != NULL; i = i->ifa_next) {
				if (i->ifa_addr == NULL || i->ifa_addr->sa_family != AF_LINK)
					continue;
				sdl = (struct sockaddr_dl *)i->ifa_addr;
				if (sdl->sdl_alen == 6 && memcmp(LLADDR(sdl), want, 6) == 0) {
					snprintf(name, len, "%s", i->ifa_name);
					freeifaddrs(ifa);
					return (true);
				}
			}
			freeifaddrs(ifa);
		}
		usleep(500000);
	}
	return (false);
}

/* resolv.conf dal JSON del DNS ("ServerList":"a,b", "Search":"x,y"); nella distro se e' montata */
static int
write_resolv_conf(const char *json)
{
	char servers[512], search[512], *p, *t;
	FILE *f;

	if (!json_get(json, "ServerList", servers, sizeof(servers)))
		servers[0] = '\0';
	if (!json_get(json, "Search", search, sizeof(search)))
		search[0] = '\0';
	if ((f = fopen(RESOLV_CONF, "w")) == NULL)
		return (errno);
	fprintf(f, "# generato da claude-wslinit con i DNS del servizio WSL\n");
	for (p = search; *p == ','; p++)
		;
	if (*p != '\0') {
		fprintf(f, "search");
		for (t = strtok(p, ","); t != NULL; t = strtok(NULL, ","))
			fprintf(f, " %s", t);
		fprintf(f, "\n");
	}
	for (t = strtok(servers, ","); t != NULL; t = strtok(NULL, ","))
		fprintf(f, "nameserver %s\n", t);
	fclose(f);
	if (is_mounted(DISTRO_PATH) && wslconf_bool(DISTRO_PATH, "network", "generateResolvConf", true))
		(void)run((const char *const[]){ "/bin/cp", RESOLV_CONF, DISTRO_PATH "/etc/resolv.conf", NULL });
	return (0);
}

static int
gns_interface_configuration(const char *json, char *ifname, size_t len)
{
	char mac[64], ip[64], prefix[8], addr[80];

	if (!json_get(json, "MacAddress", mac, sizeof(mac)) || !iface_by_mac(mac, ifname, len)) {
		warnx("gns: nessuna scheda col MAC '%s'", json_get(json, "MacAddress", mac, sizeof(mac)) ? mac : "?");
		return (ENODEV);
	}
	if (!json_get(json, "IPAddress", ip, sizeof(ip)) || *ip == '\0') {
		warnx("gns: %s senza indirizzo (arrivera' con una notifica)", ifname);
		return (run((const char *const[]){ "/sbin/ifconfig", ifname, "up", NULL }) == 0 ? 0 : EIO);
	}
	if (!json_get(json, "PrefixLength", prefix, sizeof(prefix)))
		snprintf(prefix, sizeof(prefix), "24");
	snprintf(addr, sizeof(addr), "%s/%s", ip, prefix);
	warnx("gns: %s (MAC %s) -> inet %s", ifname, mac, addr);
	return (run((const char *const[]){ "/sbin/ifconfig", ifname, "inet", addr, "up", NULL }) == 0 ? 0 : EIO);
}

static int
gns_notification(const char *json, const char *ifname)
{
	char type[32], req[32], v[128], fam[8];

	if (!json_get(json, "ResourceType", type, sizeof(type)))
		return (EINVAL);
	if (!json_get(json, "RequestType", req, sizeof(req)))
		snprintf(req, sizeof(req), "Add");
	if (strcmp(type, "Route") == 0) {
		char hop[64], dest[64];

		if (json_get(json, "Family", fam, sizeof(fam)) && strcmp(fam, "2") != 0) {
			warnx("gns: rotta di famiglia %s ignorata (solo IPv4 per ora)", fam);
			return (0);
		}
		if (!json_get(json, "NextHop", hop, sizeof(hop)) || !json_get(json, "DestinationPrefix", dest, sizeof(dest)))
			return (EINVAL);
		warnx("gns: rotta %s %s via %s", req, dest, hop);
		if (strcmp(dest, "0.0.0.0/0") == 0)
			snprintf(dest, sizeof(dest), "default");
		if (strcmp(req, "Remove") == 0)
			return (run((const char *const[]){ "/sbin/route", "-q", "delete", dest, hop, NULL }) == 0 ? 0 : EIO);
		(void)run((const char *const[]){ "/sbin/route", "-q", "delete", dest, NULL });
		return (run((const char *const[]){ "/sbin/route", "-q", "add", dest, hop, NULL }) == 0 ? 0 : EIO);
	}
	if (strcmp(type, "DNS") == 0) {
		warnx("gns: DNS %s", json_get(json, "ServerList", v, sizeof(v)) ? v : "(nessuno)");
		return (write_resolv_conf(json));
	}
	if (strcmp(type, "Interface") == 0) {
		if (json_get(json, "NlMtu", v, sizeof(v)) && atoi(v) > 0 && *ifname != '\0') {
			warnx("gns: %s mtu %s", ifname, v);
			return (run((const char *const[]){ "/sbin/ifconfig", ifname, "mtu", v, NULL }) == 0 ? 0 : EIO);
		}
		return (0);
	}
	warnx("gns: risorsa %s (%s) non gestita", type, req);
	return (0);
}

static void
gns_engine(int fd)
{
	struct chan c = { fd, 0, "gns", 0 };
	struct gns_result r;
	char ifname[IFNAMSIZ] = "";
	char *m;

	while ((m = chan_recv(&c)) != NULL) {
		struct msg_header *h = (struct msg_header *)m;

		memset(&r, 0, sizeof(r));
		switch (h->type) {
		case MSG_GNS_INTERFACE_CONFIGURATION:
			warnx("gns: InterfaceConfiguration %s", m + sizeof(*h));
			r.result = gns_interface_configuration(m + sizeof(*h), ifname, sizeof(ifname));
			break;
		case MSG_GNS_NOTIFICATION:
			/* dopo l'intestazione: AdapterId (GUID, 16 byte), poi il JSON */
			warnx("gns: Notification %s", m + sizeof(*h) + 16);
			r.result = gns_notification(m + sizeof(*h) + 16, ifname);
			break;
		default:
			warnx("gns: tipo %u (%s): niente da fare", h->type, m + sizeof(*h));
			break;
		}
		r.h.type = MSG_GNS_RESULT;
		chan_send(&c, &r, sizeof(r), h);
		warnx("gns: risposto %d", r.result);
		free(m);
	}
	warnx("gns: il servizio ha chiuso il canale");
	_exit(0);
}

/*
 * Inoltro di localhost (port tracker di tipo Relay, modalita' NAT; localhost.cpp in Linux, wslrelay/localhost.cpp
 * in Windows). Sul canale del port tracker:
 *   - SET_PORT_LISTENER (58) {HvSocketPort}: la porta hvsock su cui Windows si collega per ogni connessione;
 *   - ogni secondo, le porte TCP in ascolto: transazioni PortListenerRelayStart/Stop (59/60) {Family, Port, Address}
 *     con le famiglie di LINUX (2, 10); Windows inoltra solo quelle su any o loopback.
 * Ogni connessione da Windows porta un START_SOCKET_RELAY (15) {Family, Port, BufferSize}: ci si collega a
 * 127.0.0.1:Port (o ::1) e si copiano i byte. Un processo per direzione, letture bloccanti: niente kqueue su hv_sock.
 */
struct port_listener {
	struct msg_header h;
	int32_t hv_socket_port;
};

struct port_relay {
	struct msg_header h;
	uint16_t family;
	uint16_t port;
	uint32_t address[4];
};
_Static_assert(sizeof(struct port_relay) == 36, "LX_GNS_PORT_LISTENER_RELAY");

struct start_socket_relay {
	struct msg_header h;
	uint16_t family;
	uint16_t port;
	uint64_t buffer_size;
};
_Static_assert(sizeof(struct start_socket_relay) == 32, "LX_INIT_START_SOCKET_RELAY");

/* manda una RICHIESTA di transazione a cui non si aspetta risposta (come transaction.Send in localhost.cpp) */
static void
chan_send_request(struct chan *c, void *m, uint32_t size)
{
	struct msg_header *h = m;

	h->size = size;
	h->transaction_id = ++c->tx;
	h->transaction_step = 1;
	write_all(c->fd, m, size);
}

/* copia da a b finche' a non chiude, poi chiude in scrittura b */
static void
copy_until_eof(int a, int b)
{
	char buf[16384];
	ssize_t n;

	while ((n = read(a, buf, sizeof(buf))) > 0)
		if (!write_some(b, buf, n))
			break;
	(void)shutdown(b, SHUT_WR);
}

static void
socket_relay(int hv)
{
	struct start_socket_relay sr;
	struct sockaddr_in sin;
	struct sockaddr_in6 sin6;
	pid_t pid;
	int tcp;

	if (!read_all(hv, &sr, sizeof(sr)) || sr.h.type != MSG_START_SOCKET_RELAY)
		_exit(1);
	if (sr.family == LX_AF_INET) {
		memset(&sin, 0, sizeof(sin));
		sin.sin_len = sizeof(sin);
		sin.sin_family = AF_INET;
		sin.sin_port = htons(sr.port);
		sin.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
		tcp = socket(AF_INET, SOCK_STREAM, 0);
		if (tcp < 0 || connect(tcp, (struct sockaddr *)&sin, sizeof(sin)) < 0) {
			warn("porte: connect 127.0.0.1:%u", sr.port);
			_exit(1);
		}
	} else if (sr.family == LX_AF_INET6) {
		memset(&sin6, 0, sizeof(sin6));
		sin6.sin6_len = sizeof(sin6);
		sin6.sin6_family = AF_INET6;
		sin6.sin6_port = htons(sr.port);
		sin6.sin6_addr = in6addr_loopback;
		tcp = socket(AF_INET6, SOCK_STREAM, 0);
		if (tcp < 0 || connect(tcp, (struct sockaddr *)&sin6, sizeof(sin6)) < 0) {
			warn("porte: connect [::1]:%u", sr.port);
			_exit(1);
		}
	} else
		_exit(1);
	pid = fork();
	if (pid == 0) {
		copy_until_eof(hv, tcp);
		_exit(0);
	}
	copy_until_eof(tcp, hv);
	if (pid > 0)
		(void)waitpid(pid, NULL, 0);
	_exit(0);
}

/* le porte TCP in ascolto: "root  sshd  123  4  tcp4  *:22  *:*" (sockstat del sistema, allineato al kernel) */
#define MAX_PORTS 256
static int
listening_ports(struct port_relay *out, int max)
{
	char buf[65536], *line, *rest, *f[16], *local, *colon;
	int n = 0, nf;

	if (run_out((const char *const[]){ "/usr/bin/sockstat", "-46", "-l", "-q", "-P", "tcp", NULL }, buf,
	    sizeof(buf), 10) != 0)
		return (-1);
	for (rest = buf; (line = strsep(&rest, "\n")) != NULL && n < max; ) {
		for (nf = 0; nf < 16 && (f[nf] = strsep(&line, " \t")) != NULL; )
			if (*f[nf] != '\0')
				nf++;
		if (nf < 6)
			continue;
		local = f[nf - 2];
		if ((colon = strrchr(local, ':')) == NULL)
			continue;
		*colon = '\0';
		memset(&out[n], 0, sizeof(out[n]));
		out[n].port = (uint16_t)atoi(colon + 1);
		if (strcmp(f[nf - 3], "tcp4") == 0 || strcmp(f[nf - 3], "tcp46") == 0) {
			struct in_addr a;

			out[n].family = LX_AF_INET;
			if (strcmp(local, "*") != 0) {
				if (inet_pton(AF_INET, local, &a) != 1)
					continue;
				out[n].address[0] = a.s_addr;
			}
		} else if (strcmp(f[nf - 3], "tcp6") == 0) {
			struct in6_addr a6;

			out[n].family = LX_AF_INET6;
			if (strcmp(local, "*") != 0) {
				if (*local == '[')
					local++;
				local[strcspn(local, "]")] = '\0';
				if (inet_pton(AF_INET6, local, &a6) != 1)
					continue;
				memcpy(out[n].address, &a6, sizeof(a6));
			}
		} else
			continue;
		n++;
	}
	return (n);
}

static bool
same_port(const struct port_relay *a, const struct port_relay *b)
{
	return (a->family == b->family && a->port == b->port && memcmp(a->address, b->address, sizeof(a->address)) == 0);
}

static void
port_tracker(int fd)
{
	static struct port_relay cur[MAX_PORTS], prev[MAX_PORTS];
	struct chan c = { fd, 0, "porte", 0 };
	struct port_listener pl;
	uint32_t port;
	int lfd, s, ncur, nprev = 0, i, j;
	bool found;

	lfd = listen_any(&port, 16);
	memset(&pl, 0, sizeof(pl));
	pl.h.type = MSG_GNS_SET_PORT_LISTENER;
	pl.hv_socket_port = (int32_t)port;
	chan_send(&c, &pl, sizeof(pl), NULL);
	warnx("porte: inoltro di localhost sulla porta hvsock %u", port);

	if (fork() == 0) {
		/* chi accetta le connessioni da Windows */
		close(fd);
		for (;;) {
			s = accept(lfd, NULL, NULL);
			if (s < 0) {
				if (errno == EINTR)
					continue;
				err(1, "porte: accept");
			}
			if (fork() == 0) {
				close(lfd);
				socket_relay(s);
			}
			close(s);
		}
	}
	close(lfd);

	for (;;) {
		ncur = listening_ports(cur, MAX_PORTS);
		if (ncur >= 0) {
			for (i = 0; i < nprev; i++) {
				for (found = false, j = 0; j < ncur && !found; j++)
					found = same_port(&prev[i], &cur[j]);
				if (!found) {
					prev[i].h.type = MSG_GNS_PORT_RELAY_STOP;
					chan_send_request(&c, &prev[i], sizeof(prev[i]));
					warnx("porte: %u (famiglia %u) non piu' in ascolto", prev[i].port, prev[i].family);
				}
			}
			for (j = 0; j < ncur; j++) {
				for (found = false, i = 0; i < nprev && !found; i++)
					found = same_port(&prev[i], &cur[j]);
				if (!found) {
					cur[j].h.type = MSG_GNS_PORT_RELAY_START;
					chan_send_request(&c, &cur[j], sizeof(cur[j]));
					warnx("porte: %u (famiglia %u) in ascolto: inoltro da Windows", cur[j].port, cur[j].family);
				}
			}
			memcpy(prev, cur, sizeof(cur[0]) * (size_t)ncur);
			nprev = ncur;
		}
		sleep(1);
	}
}

/* l'init della distro, processo figlio per ogni istanza (anche la distro di sistema, se chiesta) */
static void
distro_init(int fd, const char *launch, const char *what, bool distro_disk)
{
	const struct launch_init *li = (const struct launch_init *)launch;
	struct create_instance_result res;
	struct result_bool rb;
	struct chan c = { fd, 0, what, 0 };
	char *m;

	warnx("%s: pid %d, distro '%s', disco lun %u (%s, %s), flag 0x%x", what, getpid(),
	    msg_str(launch, li->distribution_name_offset), li->device_id, msg_str(launch, li->fs_type_offset),
	    msg_str(launch, li->mount_options_offset), li->flags);
	memset(&res, 0, sizeof(res));
	res.h.type = MSG_CREATE_INSTANCE_RESULT;
	res.pid = (uint64_t)getpid();
	if (distro_disk) {
		/* la distro FreeBSD dell'utente: il suo disco diventa la radice di tutto quello che l'istanza lancia */
		res.result = mount_distro(li->device_id, (li->flags & LAUNCH_FLAG_READ_ONLY) != 0, true);
		res.failure_step = 1;		/* LxInitCreateInstanceStepMountDisk */
		if (res.result == 0 && access(DISTRO_PATH "/bin/sh", X_OK) < 0) {
			warn("%s: %s/bin/sh", what, DISTRO_PATH);
			res.result = ENOENT;
			res.failure_step = 3;	/* LxInitCreateInstanceStepLaunchInit */
		}
		/* tutti i discendenti (sessioni, comandi, loro figli) restano sotto l'istanza: alla fine si chiudono tutti */
		if (procctl(P_PID, getpid(), PROC_REAP_ACQUIRE, NULL) < 0)
			warn("%s: PROC_REAP_ACQUIRE", what);
	}
	chan_send(&c, &res, sizeof(res), NULL);
	warnx("%s: CreateInstanceResult mandato (risultato %d)", what, res.result);
	if (res.result != 0)
		_exit(1);

	while ((m = chan_recv(&c)) != NULL) {
		struct msg_header *h = (struct msg_header *)m;

		switch (h->type) {
		case MSG_INITIALIZE:
			initialize_instance(&c, m);
			break;
		case MSG_CREATE_SESSION:
			create_session(&c, m);
			break;
		case MSG_TIMEZONE_INFORMATION:
			if (distro_disk)
				apply_timezone(msg_str(m, *(uint32_t *)(m + sizeof(*h))));
			break;
		case MSG_TERMINATE_INSTANCE:
			if (distro_disk)
				unmount_distro(what);
			memset(&rb, 0, sizeof(rb));
			rb.h.type = MSG_RESULT_BOOL;
			rb.result = true;
			chan_send(&c, &rb, sizeof(rb), h);
			warnx("%s: TerminateInstance, fine", what);
			_exit(0);
		default:
			warnx("%s: tipo %u non gestito%s", what, h->type,
			    h->transaction_step == 1 ? " (e' una RICHIESTA: il servizio aspetta una risposta)" : "");
			break;
		}
		free(m);
	}
	warnx("%s: il servizio ha chiuso il canale", what);
	_exit(0);
}

/*
 * ChildExit (45) sul canale delle notifiche quando muore l'init di un'istanza (main.cpp in Linux): il servizio lo
 * aspetta per chiudere l'istanza; senza, wsl --terminate attendeva 60 s ("Timeout durante l'attesa della chiusura
 * del processo di distribuzione", prova del 03/11 19:58). Lo manda il gestore di SIGCHLD del processo principale:
 * write() e waitpid() si possono chiamare da un gestore; la tabella si tocca solo con SIGCHLD bloccato.
 */
struct child_exit {
	struct msg_header h;
	uint32_t child_pid;
	uint8_t instance_id[16];
};
_Static_assert(sizeof(struct child_exit) == 36, "LX_MINI_INIT_CHILD_EXIT_MESSAGE");

static struct {
	pid_t pid;
	uint8_t instance_id[16];
} instances[64];
static int notify_fd = -1;

static void
on_sigchld(int sig __unused)
{
	struct child_exit m;
	int saved = errno, status;
	size_t i;
	pid_t p;

	while ((p = waitpid(-1, &status, WNOHANG)) > 0)
		for (i = 0; i < nitems(instances); i++)
			if (instances[i].pid == p) {
				memset(&m, 0, sizeof(m));
				m.h.type = MSG_CHILD_EXIT;
				m.h.size = sizeof(m);
				m.child_pid = (uint32_t)p;
				memcpy(m.instance_id, instances[i].instance_id, sizeof(m.instance_id));
				if (notify_fd >= 0)
					(void)write(notify_fd, &m, sizeof(m));
				instances[i].pid = 0;
			}
	errno = saved;
}

/* nei figli del processo principale: niente gestore ereditato, i loro figli non lasciano zombi */
static void
child_of_main(void)
{
	signal(SIGCHLD, SIG_IGN);
}

static void
launch_init(struct chan *mainc, int notify, const char *msg, bool gui)
{
	const struct launch_init *li = (const struct launch_init *)msg;
	int fd, sysfd;
	pid_t pid;

	fd = connect_host(WSL_INIT_PORT);
	sysfd = -1;
	if ((li->flags & LAUNCH_FLAG_SYSTEM_DISTRO) != 0 && gui)
		sysfd = connect_host(WSL_INIT_PORT);
	sigset_t block, old;
	size_t i;

	sigemptyset(&block);
	sigaddset(&block, SIGCHLD);
	sigprocmask(SIG_BLOCK, &block, &old);
	pid = fork();
	if (pid < 0)
		err(1, "fork");
	if (pid == 0) {
		sigprocmask(SIG_SETMASK, &old, NULL);
		child_of_main();
		close(mainc->fd);
		close(notify);
		if (sysfd >= 0 && fork() == 0) {
			close(fd);
			distro_init(sysfd, msg, "distro di sistema", false);
		}
		if (sysfd >= 0)
			close(sysfd);
		distro_init(fd, msg, "istanza", true);
	}
	for (i = 0; i < nitems(instances); i++)
		if (instances[i].pid == 0) {
			instances[i].pid = pid;
			memcpy(instances[i].instance_id, li->instance_id, sizeof(li->instance_id));
			break;
		}
	sigprocmask(SIG_SETMASK, &old, NULL);
	close(fd);
	if (sysfd >= 0)
		close(sysfd);
}

int
main(void)
{
	struct chan mainc = { -1, 0, "principale", 0 };
	char *msg;
	int notify, extra;
	bool gui = false;

	setvbuf(stderr, NULL, _IONBF, 0);
	struct sigaction sa;

	/* SIGCHLD raccoglie i figli e segnala la fine delle istanze; SA_RESTART: le letture dei canali proseguono */
	memset(&sa, 0, sizeof(sa));
	sa.sa_handler = on_sigchld;
	sa.sa_flags = SA_RESTART | SA_NOCLDSTOP;
	sigemptyset(&sa.sa_mask);
	sigaction(SIGCHLD, &sa, NULL);
	{
		/* (punto 3) quanto dopo l'avvio del kernel parte l'init: il servizio aspetta la prima connessione */
		struct timespec up;

		clock_gettime(CLOCK_UPTIME, &up);
		warnx("avvio, pid %d, %ld.%01ld s dopo l'avvio del kernel", getpid(), (long)up.tv_sec,
		    up.tv_nsec / 100000000);
	}

	mainc.fd = connect_host(WSL_INIT_PORT);
	send_capabilities(&mainc);
	notify = connect_host(WSL_INIT_PORT);
	notify_fd = notify;

	while ((msg = chan_recv(&mainc)) != NULL) {
		struct msg_header *h = (struct msg_header *)msg;

		switch (h->type) {
		case MSG_EARLY_CONFIG: {
			struct early_config *e = (struct early_config *)msg;

			warnx("EarlyConfig: swap lun %u, distro di sistema tipo %u id %u, dns tunneling %d, "
			    "debug shell %d", e->swap_lun, e->system_distro_device_type, e->system_distro_device_id,
			    e->enable_dns_tunneling, e->enable_debug_shell);
			warnx("EarlyConfig: hostname '%s'", msg_str(msg, e->hostname_offset));
			extra = connect_host(WSL_INIT_PORT);	/* canale GNS */
			warnx("canale GNS fd %d", extra);
			if (fork() == 0) {
				child_of_main();
				close(mainc.fd);
				close(notify);
				gns_engine(extra);
			}
			close(extra);
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
			gui = c->enable_gui_apps;
			if (c->net.port_tracker_type == 1 || c->net.port_tracker_type == 2) {
				extra = connect_host(WSL_INIT_PORT);
				warnx("canale port tracker fd %d", extra);
				if (c->net.port_tracker_type == 2 && fork() == 0) {
					child_of_main();
					close(mainc.fd);
					close(notify);
					port_tracker(extra);
				}
				close(extra);
			}
			warnx("I1: inizializzazione della VM completata dal lato FreeBSD");
			break;
		}
		case MSG_LAUNCH_INIT:
			warnx("LaunchInit: avvio di una distro richiesto");
			launch_init(&mainc, notify, msg, gui);
			break;
		case MSG_EJECT_VHD: {
			/* EJECT_VHD_MESSAGE {Lun}: il servizio sta per staccare il disco; prima va smontato */
			struct result_int32 r;
			uint32_t lun = *(uint32_t *)(msg + sizeof(*h));
			int rc = 0;

			if (is_mounted(DISTRO_PATH "/dev"))
				(void)run((const char *const[]){ "/sbin/umount", "-f", DISTRO_PATH "/dev", NULL });
			if (is_mounted(DISTRO_PATH))
				rc = run((const char *const[]){ "/sbin/umount", "-f", DISTRO_PATH, NULL });
			warnx("EjectVhd: lun %u, smontaggio di %s -> %d", lun, DISTRO_PATH, rc);
			memset(&r, 0, sizeof(r));
			r.h.type = MSG_RESULT_INT32;
			r.result = rc == 0 ? 0 : EBUSY;
			chan_send(&mainc, &r, sizeof(r), h);
			break;
		}
		case MSG_IMPORT_INPLACE: {
			int fd = connect_host(WSL_INIT_PORT);
			pid_t pid = fork();

			if (pid < 0)
				err(1, "fork");
			if (pid == 0) {
				child_of_main();
				close(mainc.fd);
				close(notify);
				import_inplace(fd, msg);
			}
			close(fd);
			break;
		}
		default:
			warnx("tipo %u non gestito%s", h->type,
			    h->transaction_step == 1 ? " (e' una RICHIESTA: il servizio aspetta una risposta)" : "");
			break;
		}
		free(msg);
	}
	warnx("il servizio ha chiuso il canale principale");
	return (0);
}
