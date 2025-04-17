savedcmd_spawn.mod := printf '%s\n'   spawn.o | awk '!x[$$0]++ { print("./"$$0) }' > spawn.mod
