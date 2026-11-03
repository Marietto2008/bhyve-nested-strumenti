echo WSL_INTEROP=$WSL_INTEROP WSL_SYSTEMROOT=$WSL_SYSTEMROOT
command -v wslexe
wslexe whoami
wslexe hostname
wslexe cmd /c exit 7; echo codice di uscita da Windows: $?
wslexe start notepad; echo notepad lanciato, codice $?
