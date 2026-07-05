#define _GNU_SOURCE
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static char *copy_env_pair(const char *name) {
    const char *value = getenv(name);
    if (value == NULL) {
        value = "";
    }

    size_t len = strlen(name) + 1 + strlen(value) + 1;
    char *pair = malloc(len);
    if (pair == NULL) {
        return NULL;
    }

    snprintf(pair, len, "%s=%s", name, value);
    return pair;
}

int main(int argc, char **argv) {
    if (setresgid(0, 0, 0) != 0 || setresuid(0, 0, 0) != 0) {
        fprintf(stderr, "parallels-touchid-pam: failed to become root: %s\n", strerror(errno));
        return 126;
    }

    const char *names[] = {
        "PAM_USER",
        "PAM_SERVICE",
        "PAM_TTY",
        "PAM_RHOST",
        "PAM_RUSER",
        "PAM_TYPE",
        NULL
    };

    char *envp[10];
    size_t env_index = 0;
    envp[env_index++] = "PATH=/usr/sbin:/usr/bin:/sbin:/bin";
    envp[env_index++] = "PYTHONSAFEPATH=1";

    for (size_t i = 0; names[i] != NULL; i++) {
        char *pair = copy_env_pair(names[i]);
        if (pair == NULL) {
            fprintf(stderr, "parallels-touchid-pam: out of memory\n");
            return 127;
        }
        envp[env_index++] = pair;
    }
    envp[env_index] = NULL;

    char **child_argv = calloc((size_t)argc + 4, sizeof(char *));
    if (child_argv == NULL) {
        fprintf(stderr, "parallels-touchid-pam: out of memory\n");
        return 127;
    }

    size_t arg_index = 0;
    child_argv[arg_index++] = "/usr/bin/python3";
    child_argv[arg_index++] = "-I";
    child_argv[arg_index++] = "/usr/local/libexec/parallels-touchid-pam.py";
    for (int i = 1; i < argc; i++) {
        child_argv[arg_index++] = argv[i];
    }
    child_argv[arg_index] = NULL;

    execve("/usr/bin/python3", child_argv, envp);
    fprintf(stderr, "parallels-touchid-pam: exec failed: %s\n", strerror(errno));
    return 127;
}
