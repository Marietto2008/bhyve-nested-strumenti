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
#include <sys/mount.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/utsname.h>
#include <sys/wait.h>
#include <err.h>
#include <errno.h>
#include <limits.h>
#include <signal.h>
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
#define MSG_RESULT_BOOL			76
#define MSG_RESULT_INT32		77
#define MSG_RESULT_UINT32		78

#define LAUNCH_FLAG_READ_ONLY		0x1	/* LxMiniInitMessageFlagMountReadOnly */
#define LAUNCH_FLAG_SYSTEM_DISTRO	0x4	/* LxMiniInitMessageFlagLaunchSystemDistro */
#define PROCESS_FLAG_ALLOW_OOBE		0x20	/* LxInitCreateProcessFlagAllowOOBE */
#define SHELL_OPTIONS_LOGIN		0x1	/* ShellOptionsLogin */
#define PROCESS_SOCKETS			5	/* LX_INIT_UTILITY_VM_CREATE_PROCESS_SOCKET_COUNT */
#define DISTRO_PATH			"/distro"	/* qui si monta il disco della distro FreeBSD */

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

struct exit_status {
	struct msg_header h;
	int32_t exit_code;
};

/* un canale: il socket e il contatore dei messaggi fuori transazione mandati */
struct chan {
	int fd;
	uint32_t sent;
	const char *name;
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
 * Il processo del comando: stdin/stdout/stderr sui socket, ambiente dal servizio con PATH/HOME di FreeBSD.
 * Nome vuoto = shell (come init.cpp: argv[0] "-sh" se e' chiesta la shell di login), altrimenti execvp del nome
 * con la riga di comando cosi' com'e'.
 */
static void
exec_command(const char *msg, int sockets[])
{
	const struct create_process *cp = (const struct create_process *)msg;
	const char *filename, *cwd;
	char **argv, **env, **full;
	int argc, envc, i;

	for (i = 0; i < 3; i++)
		if (dup2(sockets[i], i) < 0)
			err(1, "dup2");
	for (i = 3; i < 64; i++)
		close(i);
	setsid();

	filename = msg_str(msg, cp->filename_offset);
	cwd = msg_str(msg, cp->cwd_offset);
	argv = msg_strarray(msg, cp->command_line_offset, &argc);
	env = msg_strarray(msg, cp->environment_offset, &envc);

	clearenv();
	for (i = 0; i < envc; i++)
		putenv(env[i]);
	setenv("PATH", "/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin", 1);
	setenv("HOME", "/root", 1);
	setenv("USER", "root", 1);
	setenv("SHELL", "/bin/sh", 1);

	if (*cwd == '\0' || *cwd == '~' || chdir(cwd) < 0)
		if (chdir("/root") < 0)
			(void)chdir("/");

	if (*filename == '\0') {
		full = calloc((size_t)argc + 2, sizeof(*full));
		if (full == NULL)
			err(1, "calloc");
		full[0] = (cp->shell_options & SHELL_OPTIONS_LOGIN) ? "-sh" : "/bin/sh";
		for (i = 0; i < argc; i++)
			full[i + 1] = argv[i];
		execv("/bin/sh", full);
		err(127, "execv(/bin/sh)");
	}
	if (argc == 0) {
		argv = realloc(argv, 2 * sizeof(*argv));
		argv[0] = strdup(filename);
		argv[1] = NULL;
	}
	execvp(filename, argv);
	err(127, "execvp(%s)", filename);
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
	int argc, i, lfd, nsock, status;
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
	child = fork();
	if (child < 0)
		err(1, "fork");
	if (child == 0)
		exec_command(msg, sockets);
	for (i = 0; i < 3; i++)
		close(sockets[i]);
	while (waitpid(child, &status, 0) < 0)
		if (errno != EINTR)
			err(1, "waitpid");
	memset(&es, 0, sizeof(es));
	es.h.type = MSG_EXIT_STATUS;
	es.exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
	warnx("CreateProcess: pid %d finito, codice %d", child, es.exit_code);
	/*
	 * Lo stato d'uscita va sul quinto socket (interop): e' li' che wsl.exe lo aspetta (VmModeWorkerThread,
	 * svccomm.cpp) e lo rimanda indietro come conferma. Il quarto (controllo del terminale) porta solo i cambi di
	 * dimensione della finestra.
	 */
	ctl = (struct chan){ sockets[4], 0, "interop" };
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
	struct chan c = { fd, 0, "sessione" };
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
	char version[64];
	const char flavor[] = "freebsd";
	size_t size;

	hostname = msg_str(msg, ic->hostname_offset);
	warnx("Initialize: distro '%s', hostname '%s', dominio '%s', fuso '%s', funzioni 0x%x, proprietario drvfs %u",
	    msg_str(msg, ic->distribution_name_offset), hostname, msg_str(msg, ic->domainname_offset),
	    msg_str(msg, ic->timezone_offset), ic->feature_flags, ic->drvfs_default_owner);
	if (*hostname != '\0' && sethostname(hostname, (int)strlen(hostname)) < 0)
		warn("sethostname");

	os_version(version, sizeof(version));
	size = sizeof(*r) + sizeof(flavor) + strlen(version) + 1;
	r = calloc(1, size);
	if (r == NULL)
		err(1, "calloc");
	r->h.type = MSG_INITIALIZE_RESPONSE;
	r->plan9_port = WSL_INVALID_PORT;
	r->default_uid = 0;
	r->interop_port = WSL_INVALID_PORT;
	r->systemd_enabled = false;
	r->pid_namespace = 0;
	r->flavor_index = (uint32_t)sizeof(*r);
	memcpy(r->buffer, flavor, sizeof(flavor));
	r->version_index = (uint32_t)(sizeof(*r) + sizeof(flavor));
	memcpy(r->buffer + sizeof(flavor), version, strlen(version) + 1);
	chan_send(c, r, (uint32_t)size, &ic->h);
	warnx("Initialize: risposto (uid predefinito 0, %s %s)", flavor, version);
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

/*
 * Esegue un programma e ne aspetta la fine; ritorna il codice d'uscita (-1 se non e' partito o e' morto).
 * SIGCHLD torna SIG_DFL per la durata dell'attesa: con SIG_IGN (ereditato da main) il figlio verrebbe raccolto da
 * solo e waitpid darebbe ECHILD (prova del 03/11 17:16: fsck e mount riusciti ma riportati come -1).
 */
static int
run(const char *const argv[])
{
	void (*prev)(int);
	pid_t pid;
	int status, rc;

	prev = signal(SIGCHLD, SIG_DFL);
	pid = fork();
	if (pid < 0) {
		signal(SIGCHLD, prev);
		return (-1);
	}
	if (pid == 0) {
		execv(argv[0], (char *const *)argv);
		_exit(127);
	}
	rc = -1;
	while (waitpid(pid, &status, 0) < 0)
		if (errno != EINTR)
			goto out;
	rc = WIFEXITED(status) ? WEXITSTATUS(status) : -1;
out:
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
	char line[256], key[32];
	char *p, *q;
	FILE *f;
	int tries;

	snprintf(key, sizeof(key), " lun %u (", lun);
	for (tries = 0; tries < 60; tries++) {
		f = popen("/sbin/camcontrol devlist", "r");
		if (f != NULL) {
			while (fgets(line, sizeof(line), f) != NULL) {
				if ((p = strstr(line, key)) == NULL)
					continue;
				for (p += strlen(key); (q = strsep(&p, ",)")) != NULL; )
					if (strncmp(q, "da", 2) == 0) {
						snprintf(dev, len, "/dev/%s", q);
						pclose(f);
						return (true);
					}
			}
			pclose(f);
		}
		usleep(500000);
	}
	return (false);
}

/*
 * La partizione UFS del disco della distro: p4 (schema dell'installazione di FreeBSD), poi p2, p1. Il disco appena
 * collegato compare prima della sua tabella GPT (prova del 03/11 17:01: da2 c'era, da2p4 non ancora): si aspetta
 * fino a 10 s, e solo alla fine si ripiega sul disco intero.
 */
static bool
distro_partition(const char *disk, char *part, size_t len)
{
	static const char *const suffixes[] = { "p4", "p2", "p1" };
	struct stat st;
	size_t i;
	int tries;

	for (tries = 0; tries < 20; tries++) {
		for (i = 0; i < nitems(suffixes); i++) {
			snprintf(part, len, "%s%s", disk, suffixes[i]);
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

/* monta il disco della distro su DISTRO_PATH (fsck prima: wsl --shutdown spegne la VM senza smontare); 0 o errno */
static int
mount_distro(uint32_t lun, bool ro, bool with_devfs)
{
	char disk[64], part[80];
	int rc;

	if (is_mounted(DISTRO_PATH)) {
		warnx("distro: %s gia' montato", DISTRO_PATH);
		return (0);
	}
	if (!lun_device(lun, disk, sizeof(disk))) {
		warnx("distro: nessun disco al lun %u", lun);
		return (ENODEV);
	}
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
	struct chan c = { fd, 0, "importazione" };
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

/* l'init della distro, processo figlio per ogni istanza (anche la distro di sistema, se chiesta) */
static void
distro_init(int fd, const char *launch, const char *what, bool distro_disk)
{
	const struct launch_init *li = (const struct launch_init *)launch;
	struct create_instance_result res;
	struct result_bool rb;
	struct chan c = { fd, 0, what };
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
		if (res.result == 0 && (chroot(DISTRO_PATH) < 0 || chdir("/") < 0)) {
			warn("%s: chroot(%s)", what, DISTRO_PATH);
			res.result = errno;
			res.failure_step = 3;	/* LxInitCreateInstanceStepLaunchInit */
		}
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
			warnx("%s: fuso orario '%s' (radice in sola lettura: non applicato)", what,
			    msg_str(m, *(uint32_t *)(m + sizeof(*h))));
			break;
		case MSG_TERMINATE_INSTANCE:
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
	pid = fork();
	if (pid < 0)
		err(1, "fork");
	if (pid == 0) {
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
	close(fd);
	if (sysfd >= 0)
		close(sysfd);
}

int
main(void)
{
	struct chan mainc = { -1, 0, "principale" };
	char *msg;
	int notify, extra;
	bool gui = false;

	setvbuf(stderr, NULL, _IONBF, 0);
	signal(SIGCHLD, SIG_IGN);	/* i figli (istanze, sessioni) non lasciano zombi */
	warnx("avvio, pid %d", getpid());

	mainc.fd = connect_host(WSL_INIT_PORT);
	send_capabilities(&mainc);
	notify = connect_host(WSL_INIT_PORT);

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
