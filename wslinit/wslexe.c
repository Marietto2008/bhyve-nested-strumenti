/*
 * wslexe.c -- Claude 03/11/2026. Lancia un programma di Windows dalla distro FreeBSD di WSL (interop).
 * In Linux lo fa l'interprete binfmt di WSL (binfmt.cpp, CreateNtProcessUtilityVm); qui non c'e' ancora l'accesso ai
 * dischi di Windows (/mnt/c), quindi il programma si indica per nome o per percorso Windows:
 *   wslexe C:\Windows\System32\notepad.exe [argomenti]   percorso Windows: diretto
 *   wslexe notepad [argomenti]                            nome: cmd.exe /d /c, che lo cerca nel PATH di Windows
 * Protocollo: porta hvsock in ascolto; CreateProcessUtilityVm (8) {Port, Common} al server d'interop della sessione
 * (socket unix in $WSL_INTEROP, tenuto dall'init); wsl.exe crea il processo e collega 4 socket: stdin, stdout,
 * stderr, controllo. Sul controllo: CreateProcessResponse (11) {Result, SignalPipeId, Flags}, poi ExitStatus (9).
 * Un processo per direzione, letture bloccanti (kqueue non e' affidabile sui socket hv_sock).
 */
#include <sys/param.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <err.h>
#include <errno.h>
#include <signal.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

#ifndef AF_HYPERV
#define AF_HYPERV 43
#endif

struct sockaddr_hvs {
	unsigned char	sa_len;
	sa_family_t	sa_family;
	unsigned int	hvs_port;
	unsigned char	hvs_zero[sizeof(struct sockaddr) - sizeof(sa_family_t) - sizeof(unsigned char) -
	    sizeof(unsigned int)];
};

#define MSG_CREATE_PROCESS_UVM		8
#define MSG_EXIT_STATUS			9
#define MSG_CREATE_PROCESS_RESPONSE	11

struct msg_header {
	uint32_t type;
	uint32_t size;
	uint32_t transaction_id;
	uint32_t transaction_step;
};

/* LX_INIT_CREATE_NT_PROCESS_COMMON: offset relativi all'inizio di questa struttura */
struct nt_common {
	uint32_t filename_offset;
	uint32_t cwd_offset;
	uint32_t command_line_offset;
	uint16_t command_line_count;
	uint32_t environment_offset;
	uint16_t rows;
	uint16_t columns;
	bool create_pseudoconsole;
	char buffer[];
};
_Static_assert(offsetof(struct nt_common, environment_offset) == 16, "LX_INIT_CREATE_NT_PROCESS_COMMON");
_Static_assert(offsetof(struct nt_common, buffer) == 25, "LX_INIT_CREATE_NT_PROCESS_COMMON");

struct nt_process {
	struct msg_header h;
	uint32_t port;
	struct nt_common common;
};

struct create_process_response {
	struct msg_header h;
	int32_t result;
	int64_t signal_pipe_id;
	uint32_t flags;
};

struct exit_status {
	struct msg_header h;
	int32_t exit_code;
};

static struct termios saved_tio;
static bool tio_saved;

static void
restore_tty(void)
{
	if (tio_saved)
		(void)tcsetattr(STDIN_FILENO, TCSAFLUSH, &saved_tio);
}

static bool
read_all(int fd, void *buf, size_t len)
{
	char *p = buf;
	ssize_t n;

	while (len > 0) {
		n = read(fd, p, len);
		if (n < 0 && errno == EINTR)
			continue;
		if (n <= 0)
			return (false);
		p += n;
		len -= (size_t)n;
	}
	return (true);
}

static bool
write_all(int fd, const void *buf, size_t len)
{
	const char *p = buf;
	ssize_t n;

	while (len > 0) {
		n = write(fd, p, len);
		if (n < 0 && errno == EINTR)
			continue;
		if (n <= 0)
			return (false);
		p += n;
		len -= (size_t)n;
	}
	return (true);
}

/* copia da a b finche' a non chiude; poi chiude b in scrittura */
static pid_t
copier(int a, int b, bool shut)
{
	char buf[16384];
	ssize_t n;
	pid_t pid;

	pid = fork();
	if (pid != 0)
		return (pid);
	while ((n = read(a, buf, sizeof(buf))) > 0)
		if (!write_all(b, buf, (size_t)n))
			break;
	if (shut)
		(void)shutdown(b, SHUT_WR);
	_exit(0);
}

static int
listen_any(uint32_t *port)
{
	struct sockaddr_hvs sa;
	uint32_t p;
	int fd, tries;

	p = 70000 + (uint32_t)(getpid() % 1000) * 16;
	for (tries = 0; tries < 1000; tries++, p++) {
		fd = socket(AF_HYPERV, SOCK_STREAM, 0);
		if (fd < 0)
			err(1, "socket(AF_HYPERV)");
		memset(&sa, 0, sizeof(sa));
		sa.sa_len = sizeof(sa);
		sa.sa_family = AF_HYPERV;
		sa.hvs_port = p;
		if (bind(fd, (struct sockaddr *)&sa, sizeof(sa)) == 0) {
			if (listen(fd, 4) < 0)
				err(1, "listen");
			*port = p;
			return (fd);
		}
		if (errno != EADDRINUSE)
			err(1, "bind");
		close(fd);
	}
	errx(1, "nessuna porta hvsock libera");
}

/* aggiunge una stringa (con lo zero finale) in coda al messaggio; restituisce l'offset rispetto a "base" */
static uint32_t
put_str(char **buf, size_t *len, size_t base, const char *str)
{
	size_t n = strlen(str) + 1;
	uint32_t off = (uint32_t)(*len - base);

	*buf = realloc(*buf, *len + n);
	if (*buf == NULL)
		err(1, "realloc");
	memcpy(*buf + *len, str, n);
	*len += n;
	return (off);
}

int
main(int argc, char **argv)
{
	struct sockaddr_un sun;
	struct create_process_response resp;
	struct exit_status es;
	struct nt_process *m;
	struct msg_header h;
	struct winsize ws;
	const char *interop, *sysroot, *base;
	char cmd[512], *buf = NULL;
	size_t len, cbase;
	uint32_t port;
	int lfd, ufd, s[4], i, code = 1;
	pid_t in_pid = -1, out_pid, err_pid;
	bool winpath, pty;

	if (argc < 2) {
		fprintf(stderr, "uso: wslexe <programma di Windows> [argomenti]\n"
		    "  wslexe notepad                     (cercato nel PATH di Windows, con cmd.exe)\n"
		    "  wslexe 'C:\\Windows\\System32\\whoami.exe' /user\n");
		return (2);
	}
	if ((interop = getenv("WSL_INTEROP")) == NULL)
		errx(1, "WSL_INTEROP non impostata: interop non attiva in questa sessione");
	if ((sysroot = getenv("WSL_SYSTEMROOT")) == NULL)
		sysroot = "C:\\Windows";
	winpath = strchr(argv[1], '\\') != NULL || strchr(argv[1], ':') != NULL;
	pty = isatty(STDIN_FILENO) && isatty(STDOUT_FILENO);

	lfd = listen_any(&port);

	/* il messaggio: intestazione, porta, Common, poi le stringhe */
	len = sizeof(struct nt_process);
	buf = calloc(1, len);
	if (buf == NULL)
		err(1, "calloc");
	cbase = offsetof(struct nt_process, common);
	{
		uint32_t fo, co, eo, clo;
		uint16_t count;

		if (winpath) {
			fo = put_str(&buf, &len, cbase, argv[1]);
		} else {
			snprintf(cmd, sizeof(cmd), "%s\\System32\\cmd.exe", sysroot);
			fo = put_str(&buf, &len, cbase, cmd);
		}
		co = put_str(&buf, &len, cbase, "");		/* cartella: quella di wsl.exe */
		eo = 0;						/* ambiente: quello di wsl.exe */
		if (winpath) {
			base = strrchr(argv[1], '\\') != NULL ? strrchr(argv[1], '\\') + 1 : argv[1];
			clo = put_str(&buf, &len, cbase, base);
			count = 1;
		} else {
			clo = put_str(&buf, &len, cbase, "cmd.exe");
			put_str(&buf, &len, cbase, "/d");
			put_str(&buf, &len, cbase, "/c");
			put_str(&buf, &len, cbase, argv[1]);
			count = 4;
		}
		for (i = 2; i < argc; i++, count++)
			put_str(&buf, &len, cbase, argv[i]);
		m = (struct nt_process *)buf;
		m->h.type = MSG_CREATE_PROCESS_UVM;
		m->h.size = (uint32_t)len;
		m->h.transaction_id = 1;
		m->h.transaction_step = 1;
		m->port = port;
		m->common.filename_offset = fo;
		m->common.cwd_offset = co;
		m->common.command_line_offset = clo;
		m->common.command_line_count = count;
		m->common.environment_offset = eo;
		if (pty && ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0) {
			m->common.rows = ws.ws_row;
			m->common.columns = ws.ws_col;
			m->common.create_pseudoconsole = true;
		}
	}

	ufd = socket(AF_UNIX, SOCK_STREAM, 0);
	memset(&sun, 0, sizeof(sun));
	sun.sun_family = AF_UNIX;
	snprintf(sun.sun_path, sizeof(sun.sun_path), "%s", interop);
	if (ufd < 0 || connect(ufd, (struct sockaddr *)&sun, sizeof(sun)) < 0)
		err(1, "interop %s", interop);
	if (!write_all(ufd, buf, len))
		err(1, "invio della richiesta");
	close(ufd);

	for (i = 0; i < 4; i++)
		if ((s[i] = accept(lfd, NULL, NULL)) < 0)
			err(1, "accept (socket %d)", i);
	close(lfd);

	/* con la pseudoconsole il terminale va in modo grezzo: interpreta tutto Windows */
	if (m->common.create_pseudoconsole && tcgetattr(STDIN_FILENO, &saved_tio) == 0) {
		struct termios raw = saved_tio;

		cfmakeraw(&raw);
		tio_saved = tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) == 0;
	}
	signal(SIGCHLD, SIG_DFL);
	in_pid = copier(STDIN_FILENO, s[0], true);
	out_pid = copier(s[1], STDOUT_FILENO, false);
	err_pid = copier(s[2], STDERR_FILENO, false);

	/* il canale di controllo: risposta alla creazione, poi la fine del processo */
	while (read_all(s[3], &h, sizeof(h)) && h.size >= sizeof(h) && h.size <= 4096) {
		char body[4096];

		memcpy(body, &h, sizeof(h));
		if (!read_all(s[3], body + sizeof(h), h.size - sizeof(h)))
			break;
		if (h.type == MSG_CREATE_PROCESS_RESPONSE) {
			memcpy(&resp, body, MIN(sizeof(resp), (size_t)h.size));
			if (resp.result != 0) {
				restore_tty();
				fprintf(stderr, "wslexe: Windows non ha avviato %s (errore %d)\n", argv[1], resp.result);
				break;
			}
		} else if (h.type == MSG_EXIT_STATUS) {
			memcpy(&es, body, MIN(sizeof(es), (size_t)h.size));
			code = es.exit_code;
			break;
		}
	}
	/* l'uscita del processo arriva fino alla chiusura dei socket; l'ingresso non serve piu' */
	(void)waitpid(out_pid, NULL, 0);
	(void)waitpid(err_pid, NULL, 0);
	kill(in_pid, SIGKILL);
	(void)waitpid(in_pid, NULL, 0);
	restore_tty();
	return (code);
}
