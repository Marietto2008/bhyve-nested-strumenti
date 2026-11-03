/*
 * wslg-avvia.c -- Claude 03/11/2026. Avvia la grafica di WSL (WSLg) dalla distro FreeBSD, come fa WSLGd (main.cpp nel
 * repo wslg): una porta hvsock in ascolto passata a Weston (backend RDP, USE_VSOCK=<fd>), poi il client RDP di
 * Windows (msrdc.exe /wslg) collegato a quella porta via hvsocket (/v:<id VM> /hvsocketserviceid:<porta>).
 * Weston e' weston-mirror (ramo working di Microsoft) compilato per FreeBSD in /usr/local/wslg.
 * Uso: wslg-avvia [desktop|rail]     desktop (predefinito) = un desktop Weston in una finestra; rail = finestre singole
 * Variabili: WSL_VM_ID e WSL_INSTALL_PATH (le mette l'init), WSL_INTEROP (per wslexe).
 */
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <err.h>
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define AF_HYPERV 43

struct sockaddr_hvs {
	unsigned char	sa_len;
	sa_family_t	sa_family;
	unsigned int	hvs_port;
	unsigned char	hvs_zero[sizeof(struct sockaddr) - sizeof(sa_family_t) - sizeof(unsigned char) -
	    sizeof(unsigned int)];
};

#define WESTON		"/usr/local/wslg/bin/weston"
#define RUNTIME_DIR	"/tmp/wslg-runtime"
#define SERVICE_ID_FMT	"%08X-FACB-11E6-BD58-64006A7986D3"	/* come c_serviceIdTemplate di WSLGd */

int
main(int argc, char **argv)
{
	struct sockaddr_hvs sa;
	char fdenv[32], sid[64], sidenv[96], sidarg[96], remote[96], shell[64], rdp[600], msrdc[600];
	const char *vm, *inst, *mode;
	unsigned int port;
	pid_t weston, client;
	int fd, status;

	mode = argc > 1 ? argv[1] : "desktop";
	if ((vm = getenv("WSL_VM_ID")) == NULL || (inst = getenv("WSL_INSTALL_PATH")) == NULL)
		errx(1, "WSL_VM_ID o WSL_INSTALL_PATH mancanti (li imposta claude-wslinit)");

	/* la porta hvsock del server RDP: la prima libera, come WSLGd (1 .. 1023) */
	fd = socket(AF_HYPERV, SOCK_STREAM, 0);
	if (fd < 0)
		err(1, "socket(AF_HYPERV)");
	for (port = 1; port < 1024; port++) {
		memset(&sa, 0, sizeof(sa));
		sa.sa_len = sizeof(sa);
		sa.sa_family = AF_HYPERV;
		sa.hvs_port = port;
		if (bind(fd, (struct sockaddr *)&sa, sizeof(sa)) == 0)
			break;
		if (errno != EADDRINUSE)
			err(1, "bind");
	}
	if (port == 1024 || listen(fd, 1) < 0)
		err(1, "nessuna porta hvsock per RDP");
	snprintf(sid, sizeof(sid), SERVICE_ID_FMT, port);
	printf("wslg-avvia: server RDP sulla porta hvsock %u (%s), VM %s\n", port, sid, vm);

	(void)mkdir(RUNTIME_DIR, 0700);
	(void)chmod(RUNTIME_DIR, 0700);
	snprintf(fdenv, sizeof(fdenv), "%d", fd);
	setenv("USE_VSOCK", fdenv, 1);
	snprintf(sidenv, sizeof(sidenv), "%s", sid);
	setenv("WSLG_SERVICE_ID", sidenv, 1);
	setenv("XDG_RUNTIME_DIR", RUNTIME_DIR, 1);
	setenv("WAYLAND_DISPLAY", "wayland-0", 1);
	setenv("LD_LIBRARY_PATH", "/usr/local/wslg/lib", 1);
	setenv("WESTON_DISABLE_ABSTRACT_FD", "1", 1);
	snprintf(shell, sizeof(shell), "--shell=%s", strcmp(mode, "rail") == 0 ? "rdprail-shell.so" : "desktop-shell.so");

	weston = fork();
	if (weston < 0)
		err(1, "fork");
	if (weston == 0) {
		execl(WESTON, "weston", "--backend=rdp-backend.so", "--socket=wayland-0", shell,
		    "--log=" RUNTIME_DIR "/weston.log", "--logger-scopes=log,rdp-backend", (char *)NULL);
		err(127, "%s", WESTON);
	}
	close(fd);
	sleep(3);
	if (waitpid(weston, &status, WNOHANG) == weston)
		errx(1, "weston e' uscito subito (codice %d): vedi " RUNTIME_DIR "/weston.log", WEXITSTATUS(status));

	/* il client RDP di Windows, come lo lancia WSLGd */
	snprintf(msrdc, sizeof(msrdc), "%s\\msrdc.exe", inst);
	snprintf(remote, sizeof(remote), "/v:%s", vm);
	snprintf(sidarg, sizeof(sidarg), "/hvsocketserviceid:%s", sid);
	snprintf(rdp, sizeof(rdp), "%s\\%s", inst, strcmp(mode, "rail") == 0 ? "wslg.rdp" : "wslg_desktop.rdp");
	printf("wslg-avvia: %s /wslg /silent %s %s /plugin:WSLDVC_PACKAGE %s\n", msrdc, remote, sidarg, rdp);
	client = fork();
	if (client == 0) {
		execlp("wslexe", "wslexe", msrdc, "/wslg", "/silent", remote, sidarg, "/plugin:WSLDVC_PACKAGE", rdp,
		    (char *)NULL);
		err(127, "wslexe");
	}
	/* finisce quando si chiude la finestra RDP; poi si chiude anche weston */
	(void)waitpid(client, &status, 0);
	printf("wslg-avvia: client RDP chiuso (codice %d)\n", WIFEXITED(status) ? WEXITSTATUS(status) : -1);
	kill(weston, SIGTERM);
	(void)waitpid(weston, NULL, 0);
	return (0);
}
