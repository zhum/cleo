/* empty-cleo - run processes under pseudo-terminal sessions from Cleo batch system
 *
 * Copyright (C) 2005-2008 Mikhail E. Zakharov, Sergey A. Zhumatiy
 *
 * empty originally was written by Mikhail E. Zakharov.
 * Sergey A.Zhumatiy has modified the code to be used with Cleo batch system.
 * This software was based on the basic idea of pty version 4.0
 * Copyright (c) 1992, Daniel J. Bernstein, but
 * no code was ported from pty4.
 *
 *   This code works ONLY on posix-compliant systems.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *
 *  1. Redistributions of source code must retain the above copyright
 *     notice immediately at the beginning of the file, without modification,
 *     this list of conditions, and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *  3. The name of the author may not be used to endorse or promote products
 *     derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

/*
 * Command-line arguments:
 *   ORIGINAL:
 *    -f        start new task (fork,spawn)
 *    -k SIG    send signal SIG (kill)
 *    -i fifo   use this fifo for task inpit (create if needed)
 *    -o fifo   use this fifo for task output (create if needed)
 *    -w        watch for string (Deleted here)
 *    -s        send data to task
 *    -n        do not send newline (for -s)
 *    -t N      wait N secs for -w (Unused here)
 *    -v        kvazi-verbose (unused)
 *    -h        help
 *
 *   NEW:
 *    -c input  cleo-console mode (MUST be used with -l file)
 *              EXIT FROM TERMINAL MODE - <ESC>-d
 *              KILL PROGRAM IN TERMONAL - <CTRL>-d
 *    -l FILE   use file (not FIFO) for output
 *    -e FILE   use file (not FIFO) for stderr
 *    -r FILE   use file (not FIFO) to print PID/GID/exit-code of new process
 *    -p        print task pid
 */

#include <unistd.h>
#include <sys/types.h>
#ifdef svr4
#include <stropts.h>
#endif
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <termios.h>
#ifndef svr4
#include <err.h>
#endif
#include <errno.h>
#include <sys/select.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <signal.h>
#include <stdio.h>
#include <fcntl.h>
#include <syslog.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>

#define program "empty-cleo"
#define version "0.3"

#define BUF_SIZE 1024

#ifndef O_LARGEFILE
# define O_LARGEFILE 0
#endif

/* -------------------------------------------------------------------------- */
static void usage(void);
int toint (char *intstr);
void wait4child(int child, char *argv0);
int mfifo(char *fname, int mode);
void perrx(int ex_code, const char *err_text);
void perrxslog_wargs(int ex_code, const char *err_text, ...);
void clean(void);
void fsignal(int sig);
int watch4str(int ifd, int ofd, char *get, char *resp,
              int nflg, int vflg, int timeout);
int terminal(int ifd, int ofd, int vflg);

inline int max(int a, int b){return (a>b)?a:b;}

typedef void (*sigfunc)(int);

/* make sure we sure we ignore SIGCHILD for the cases parent
   has just been stopped and not actually killed */

sigfunc posix_signal(int signo, sigfunc func ) {

    struct sigaction act, oact;

    act.sa_handler = func;
    sigemptyset(&act.sa_mask);
    act.sa_flags = SA_NOCLDSTOP|SA_RESTART;
    if (sigaction(signo, &act, &oact) < 0)
        return(SIG_ERR);
    return (oact.sa_handler);
}

/* -------------------------------------------------------------------------- */
int     master, slave, max_fd;
int     child;
int     pid;
int     ret_code=0;
char    *in = NULL, *out = NULL;
int     ifd, ofd, fd;
pid_t   master_pid=(pid_t)0;
int     status;
char    buf[BUFSIZ];
fd_set  rfd;
char    *argv0 = NULL;
int     pgrp;
char    escape_chars[]={'\033','x','0'}; /* special sequence */
char    *rflg=NULL;    /* Cleo mode - filename to print task pid */

int            term_catched=0,quit_catched=0;
volatile int   child_dead=0;
int     in_is_file=0;

void log_ret_code(int code) {
	if (rflg != NULL) {
		/* print task PID+PGRP to file*/
		FILE *outfile = fopen(rflg, "a");
		if (outfile != NULL) {
			fprintf(outfile, "CODE=%d\n", code);
			fclose(outfile);
		}
	}
}

/* -------------------------------------------------------------------------- */
int main (int argc, char *argv[]) {
  struct  winsize win;
  struct  termios tt;
  struct  timeval tv;
  int i, fdmax, cc, n, ch, escape, wn, res;

  char    *logname=NULL;          /* file to write output to */
  char    *errname=NULL;          /* file to write errors to */
  /*        char    *fifodir=NULL;          /* dir for fifo auto-creating */
  char    buftosend[1024];        /* buffer to store not sent data */

  int fflg = 0;       /* spawn, fork */
  int wflg = 0;       /* watch for string [respond] */
  int sflg = 0;       /* send */
  int kflg = 0;       /* kill */
  int iflg = 0;       /* in */
  int oflg = 0;       /* out */
  int nflg = 0;       /* DO append a newline */
  int vflg = 0;       /* kvazi verbose mode OFF */
  int cflg = 0;       /* Cleo-console mode */
  int pflg = 0;       /* Cleo mode - print task pid */
  int timeout = 10;   /* wait N secs for the response */

  int kpid = 0;
  int ksig = SIGTERM;

  char    *get = NULL, *resp = NULL;
#ifdef svr4
  char    *slave_name;
#endif

  while ((ch = getopt(argc, argv, "e:fk:wsi:c:o:r:t:nvl:ph")) != -1)
    switch (ch) {
    case 'f':
      fflg = 1;
      break;
    case 'k':
      /* Send signal */
      if ((kpid = toint(optarg)) < 0) {
        fprintf(stderr,
                "Fatal: wrong -k value\n");
        (void)usage();
      }
      kflg = 1;
      break;
    case 'w':
      wflg = 1;
      break;
    case 's':
      sflg = 1;
      break;
    case 'i':
      in = optarg;
      iflg = 1;
      break;
    case 'o':
      out = optarg;
      oflg = 1;
      break;
    case 't':
      /* wait N secs for the responce. Use with -w */
      if ((timeout = toint(optarg)) < 1) {
        fprintf(stderr,
                "Fatal: wrong -t value\n");
        (void)usage();
      }
      break;
    case 'n':
      /* do NOT append newline */
      nflg = 1;
      break;
    case 'v':
      vflg = 1;
      break;

    case 'c':
      /* Cleo-console mode */
      cflg=1;
      in = (char *)optarg;
      break;
    case 'l':
      /* Cleo-mode - use log-file */
      logname=optarg;
      break;
    case 'e':
      /* Cleo-mode - use err-file */
      errname=optarg;
      break;
    case 'r':
      /* Cleo-mode - print task pid/exitcode to file*/
      rflg=optarg;
      break;
    case 'p':
      /* Cleo-mode - print task PID */
      pflg=1;
      break;
      /*          case 'd':*/
      /*              /* Cleo-mode - use this dir for fifo making*/
      /*                              fifodir=optarg;*/
      /*              break;*/
    case 'h':
    default:
      (void)usage();
    }
  argc -= optind;
  argv += optind;

  if ((fflg + kflg + wflg + sflg + cflg) != 1)
    (void)usage();

  if(cflg && (logname==NULL)){
    printf("cflg is set, but logname - not\n");
    (void)usage();
  }


  if (kflg) { /* kill PID with the SIGNAL */
    if (argv[0])
      ksig = strtol(argv[0], (char **)NULL, 10);
    if (kill(kpid, ksig) < 0)
      (void)perrx(1, "Can't kill()");
    exit(0);
  }

  if (sflg) { /* we want to send data */
    if ((ofd = open(out, O_WRONLY)) < 0)
      (void)perrx(1, "Fatal open(out, ...)");

    if (write(ofd, argv[0], strlen(argv[0])) < 0)
      (void)perrx(1, "Fatal write(ofd, send, ...)");
    if (!nflg) { /* append the '\n' */
      if (write(ofd, "\n", 1) < 0)
        (void)perrx(1, "Fatal write(ofd, buf, ...)");
    }

    exit(0);
  }

  if (argc && (iflg && (oflg || (logname!=NULL))) == 0)
    (void)usage();

  if (wflg) { /* watch 4 string [send response] */
    switch (argc) {
    case 2:
      resp = argv[1];
    case 1:
      get = argv[0];
    }

    if ((ifd = open(in, O_RDONLY)) < 0)
      (void)perrx(1, "Fatal open(in, ...)");
    if ((ofd = open(out, O_WRONLY)) < 0)
      (void)perrx(1, "Fatal open(out, ...)");

    exit(watch4str(ifd, ofd, get, resp, nflg, vflg, timeout));
  }

  if(cflg){
    /* pseudo-terminal cleo mode */

    if ((ifd = open(logname, O_RDONLY)) < 0)
      (void)perrx(1, "Fatal open(in, ...)");
    if(vflg) printf("Opened %s for reading\n",logname);

    if ((ofd = open(in, O_WRONLY)) < 0)
      (void)perrx(1, "Fatal open(out, ...)");
    if(vflg) printf("Opened %s for writing\n",in);

    exit(terminal(ifd, ofd, vflg));
  }


  argv0 = argv[0];
  (void)openlog("empty-cleo", LOG_PID, LOG_USER);

#ifndef OpenBSD
  if ((ifd = mfifo(in, O_RDWR|O_NONBLOCK)) < 0){
    (void)syslog(LOG_NOTICE, "Warning: Cannot create input FIFO '%s': %m",in);
    in_is_file=1;
    if((ifd = open(in, O_RDONLY|O_NONBLOCK)) < 0){
      (void)perrxslog_wargs(1, "Cannot open input file '%s'",in);
    }
  }

  if(logname!=NULL){
    /* create simple file */
    if((ofd = open(logname,
                   O_WRONLY|O_CREAT|O_NONBLOCK|O_LARGEFILE|O_APPEND,
                   S_IWUSR|S_IRUSR)) < 0)
      (void)perrxslog_wargs(1, "Cannot open output file '%s'",logname);
  }
  else /* create fifo */
    if ((ofd = mfifo(out, O_RDWR|O_NONBLOCK)) < 0)
      (void)perrxslog_wargs(1, "Cannot open output FIFO '%s'",out);
#else
  if ((ifd = mfifo(in, O_RDWR|O_NONBLOCK)) < 0){
    in_is_file=1;
    (void)syslog(LOG_NOTICE, "Warning: Cannot create input FIFO '%s': %m",in);
    if((ifd = open(in, O_RDONLY|O_NONBLOCK)) < 0){
      (void)perrxslog_wargs(1, "Cannot open input file '%s'",in);
    }
  }

  if(logname!=NULL){
    /* create simple file */
    if((ofd = open(logname,
                   O_WRONLY|O_CREAT|O_NONBLOCK|O_LARGEFILE|O_APPEND)) < 0)
      (void)perrxslog_wargs(1, "Cannot open output file '%s'",logname);
  }
  else /* create fifo */
    if ((ofd = mfifo(out, O_WRONLY|O_NONBLOCK)) < 0)
      (void)perrxslog_wargs(1, "Cannot open output FIFO '%s'",out);
#endif

  (void)tcgetattr(STDIN_FILENO, &tt);
  (void)ioctl(STDIN_FILENO, TIOCGWINSZ, &win);

  if ((pid = fork()) < 0)
    (void)perrxslog_wargs(1, "Fatal fork: %m");
  if (pid > 0) exit(0);

  if (setsid() < 0)
    (void)perrxslog_wargs(1, "Fatal setsid: %m");

  if ((pid = fork()) < 0)
    (void)perrxslog_wargs(1, "Fatal fork2: %m");
  if (pid > 0) exit(0);

  for (i = 1; i < 32; i++)
    if(i==SIGCHLD){
        posix_signal(SIGCHLD,fsignal);
    }
    else{
       signal(i, fsignal);
    }

#ifndef svr4
  if (openpty(&master, &slave, NULL, &tt, &win) < 0)
    (void)perrxslog_wargs(1, "Fatal openpty: %m");
#else
  if ((master = open("/dev/ptmx", O_RDWR)) < 0)
    (void)perrxslog_wargs(1, "Fatal open(\"/dev/ptmx\"): %m");

  if (unlockpt(master) < 0)
    (void)perrxslog_wargs(1, "Fatal unlockpt(master): %m");

  if ((slave_name = (char *)ptsname(master)) == NULL)
    (void)perrxslog_wargs(1, "Fatal ptsname(master): %m");
#endif

  fcntl(master, F_SETFL,fcntl(master, F_GETFL)|O_NONBLOCK);

  /* !!!!!!!!!!!!!!!!!!!!!! This was in child section !!!!!!!!!!!!!!!!!*/
  if ((pgrp = setsid()) < 0)
    (void)syslog(LOG_NOTICE, "Can't setsid: %m");

  master_pid=getpid();
  if ((child = fork()) < 0) {
    (void)clean();
    (void)syslog(LOG_NOTICE, "Can't fork3: %m");
  }

  if (child == 0) {
    (void)close(master);

#ifndef svr4
    login_tty(slave);
    cfmakeraw(&tt);
    if(errname!=NULL){
        fd=open(errname,O_CREAT|O_LARGEFILE|O_SYNC,S_IWUSR|S_IRUSR);
        if(fd<0){
            (void)syslog(LOG_NOTICE, "(%d) open err failed: %s (%s)",
                         (int)master_pid, errname, strerror(errno));
            snprintf(buf,BUFSIZ,"Cannot open stderr '%s' (%s)\n",
                errname, strerror(errno));
            write(slave,buf,strlen(buf)+1);
        }
        else{
            dup2(fd,2);
        }
    }
#else
    /* !!!!!!!!!!!!!!!!!!!!! Here was pgrp setting !!!!!!!!!!!!!!!!!!!!!!!!!!!!!! */
    if ((slave = open(slave_name, O_RDWR)) < 0)
      (void)perrxslog_wargs(1, "(%d) Fatal open %s: %m",
                            (int)master_pid, slave_name);

    ioctl(slave, I_PUSH, "ptem");
    ioctl(slave, I_PUSH, "ldterm");
    ioctl(slave, I_PUSH, "ttcompat");

    dup2(slave, 0);
    dup2(slave, 1);

    if(errname!=NULL){
        fd=open(errname,O_CREAT|O_LARGEFILE|O_SYNC);
        if(fd<0){
           (void)syslog(LOG_NOTICE, "(%d) open err failed: %s (%m)",(int)master_pid, errname);
            snprintf(buf,BUFSIZ,"Cannot open stderr '%s' (%s)\n",
                errname, strerror(errno));
            write(slave,buf,strlen(buf)+1);
            dup2(slave, 2);
        }
        else{
            dup2(fd,2);
        }
    }
    else{
        dup2(slave, 2);
    }

    if (tcsetpgrp(0, pgrp) < 0)
      (void)perrxslog_wargs(1, "Fatal tcsetpgrp: %m");
#endif

    tt.c_lflag &= ~ECHO;
    (void)tcsetattr(STDIN_FILENO, TCSAFLUSH, &tt);

    execvp(argv[0], argv);
    (void)syslog(LOG_NOTICE, "(%d) Failed loading %s: %m", (int)master_pid, argv[0]);
    sprintf(buf,"Failed to run %s: %m\n", argv[0]);
    write(ofd,buf,strlen(buf));

    (void)clean();
    (void)kill(0, SIGTERM);
    exit(0);
  }

/* master */
  (void)syslog(LOG_NOTICE, "%s forked", argv[0]);

  if(pflg){
    /* print task PID+PGRP */
    printf("PID=%d;PGRP=%d\n",child,pgrp);
    fflush(stdout);
  }
  if(rflg!=NULL){
    /* print task PID+PGRP to file*/
	FILE *outfile=fopen(rflg,"w");
	if(outfile!=NULL){
		fprintf(outfile,"PID=%d;PGRP=%d\n",child,pgrp);
		fclose(outfile);
	}
  }

  FD_ZERO(&rfd);

  max_fd=max(master,ifd);

  for (;;) {
    // just sleep...
    tv.tv_sec = 0;
    tv.tv_usec = 50000; /* 0.05 sec */
    select(0, NULL, NULL, NULL, &tv);

    FD_SET(master, &rfd);
    FD_SET(ifd, &rfd);

    tv.tv_sec = 0;
    tv.tv_usec = 500000; /* half-second */
    n = select(max_fd+1, &rfd, 0, 0, &tv);
    escape=0;
    if ((n > 0) || (errno == EINTR)) {
      if (FD_ISSET(ifd, &rfd)){
        if ((cc = (int)read(ifd, buf, sizeof(buf))) > 0){
          for(wn=0;wn<cc;){
            res = (int)write(master, buf+wn, cc-wn);
            if(res<0){ /* error */
                break;
            }
            else{
                wn+=res;
            }
          }
        }
      }


      if (FD_ISSET(master, &rfd)){
        if ((cc = read(master, buf, sizeof(buf))) > 0){
          for(i=0;i<cc;++i){
            if(escape){
              if(escape==2){
                if(buf[i]=='x'){
                  /* just pass it */
                  (void)write(ofd, escape_chars, 2);
                  escape=0;
                }
                else{
                  /* kill task */
                  (void)clean();
                  (void)kill(0, SIGTERM);
                  sleep(5);
                  (void)kill(0, SIGKILL);
                  wait4child(child,argv0);
                  exit(ret_code);
                }
              }
              else{
                /* got escape sequence */
                escape=2;
              }
            }
            else{
              /* not in control sequence. Check for escape  */
              if(buf[i]=='\033'){
                escape=1;
              }
              else{
                (void)write(ofd, buf+i, 1);
              }
            }
          }/* end for */
        }
        else{
          /* eof or error */
          if(child_dead && (errno != EAGAIN)){
            (void)syslog(LOG_NOTICE, "%s got CHLD signal", argv0);
            break;
          }
        }
      }
      else{
        if(child_dead){
            (void)syslog(LOG_NOTICE, "%s got CHLD signal", argv0);
            break;
        }
      }
    } /* if something to read */
    else
      if(child_dead){
        /* all data is read and child is dead */
        (void)syslog(LOG_NOTICE, "%s got CHLD signal", argv0);
        break;
      }
  }/* for(;;) */
  wait4child(child, argv0);
  clean();
  return 0;
}

/* -------------------------------------------------------------------------- */
static void usage(void) {
  (void)fprintf(stderr,
                "%s-%s\n\
usage:\tempty-cleo -f -i fifo1 {-o fifo2|-l file} [-e errfile] command [command args]\n\
\tempty-cleo -w [-vn] [-t n] -i fifo2 -o fifo1 keyphrase [response]\n\
\tempty-cleo -s [-n] -o fifo1 request\n\
\tempty-cleo -c input -l output\n\
\tempty-cleo -k pid [signal]\n", program, version);
  exit(1);
}

/* -------------------------------------------------------------------------- */
int toint(char *intstr) {
  int in;

  in = strtol(intstr, (char **)NULL, 10);
  if (in == 0 && errno == EINVAL) {
    fprintf(stderr, "Wrong integer value: %s\n", intstr);
    usage();
  }
  return in;
}

/* -------------------------------------------------------------------------- */
void wait4child(int child, char *argv0) {
  while ((pid = wait3(&status, WNOHANG, 0)) > 0)
    if (pid == child){
      ret_code=WEXITSTATUS(status);
      (void)syslog(LOG_NOTICE, "%s exited; code %d", argv0, (int)ret_code);
      log_ret_code(ret_code);
    }
}

/* -------------------------------------------------------------------------- */
int mfifo(char *fname, int mode) {
  if (mkfifo(fname, S_IFIFO|S_IRWXU) < 0)
    return -1;

  return open(fname, mode);
}

/* -------------------------------------------------------------------------- */
void clean(void) {
  (void)close(master);
  (void)close(ifd);
  (void)close(ofd);
  if(!in_is_file)
    (void)unlink(in);
  if(out!=NULL)
    (void)unlink(out);
}

/* -------------------------------------------------------------------------- */
void perrx(int ex_code, const char *err_text) {
  (void)perror(err_text);
  exit(ex_code);
}

/* -------------------------------------------------------------------------- */
void perrxslog_wargs(int ex_code, const char *err_text, ...) {
  va_list ap;
  va_start(ap, err_text);

  (void)vsyslog(LOG_NOTICE, err_text, ap);
  va_end(ap);

  (void)closelog();
  exit(ex_code);
}

/* -------------------------------------------------------------------------- */
void fsignal(int sig) {
  switch(sig) {
  case SIGTERM:
    (void)syslog(LOG_NOTICE, "%s got TERM signal", argv0);
    if(term_catched)
      {sleep(5);exit(0);}
    term_catched=1;
    /* send TERM signal to all children */
    kill(0,SIGTERM);
    return;
  case SIGQUIT:
    (void)syslog(LOG_NOTICE, "%s got QUIT signal", argv0);
    if(quit_catched)
      {sleep(5);exit(0);}
    quit_catched=1;
    /* send TERM signal to all children */
    kill(0,SIGQUIT);
    return;
  case SIGINT:
  case SIGSEGV:
    break;
  case SIGCONT:
  case SIGSTOP:
    return;
  case SIGCHLD:
    /*(void)syslog(LOG_NOTICE, "%s got CHLD signal", argv0);*/
    child_dead=1;
    return;
  }

  (void)clean();
  (void)closelog();
  exit(0);
}

/* -------------------------------------------------------------------------- */
int watch4str(int ifd, int ofd, char *get, char *resp,
              int nflg, int vflg, int timeout) {

  int n, cc;
  time_t  stime, ntime;
  struct  timeval tv;

  stime = time(0);
  tv.tv_sec = timeout;
  tv.tv_usec = 0;

  FD_ZERO(&rfd);
  for (;;) {
    FD_SET(ifd, &rfd);
    n = select(ifd + 1, &rfd, 0, 0, &tv);
    if (n < 0 && errno != EINTR)
      perrx(1, "Fatal select()");

    if (FD_ISSET(ifd, &rfd)) {
      if ((cc = read(ifd, buf, sizeof(buf)-1)) > 0) {
        buf[cc] = '\0';
        if (strstr(buf, get) != NULL) {
          /* Got WHAT we EXPECTED */
          if (vflg)
            (void)printf("%s", buf);
          if (resp) {
            if (nflg)
              write(ofd, resp,
                    strlen(resp));
            else {
              sprintf(buf, "%s\n",
                      resp);
              write(ofd, buf,
                    strlen(buf));
            }
          }
          return 0;
        }
        memmove(buf, buf + cc - strlen(get) + 1,
                strlen(get) - 1);
      }

      if (cc <= 0) {
        /* Got EOF or ERROR */
        if (vflg)
          (void)fprintf(stderr,
                        "%s: Got nothing in output\n",
                        program);
        return 1;
      }
    }

    ntime = time(0);
    if ((ntime - stime) >= timeout) {
      (void)fprintf(stderr,
                    "%s: Keyphrase wasn't found. Exit on timeout\n",
                    program);
      exit(-1);
    }
  }
}

/* -------------------------------------------------------------------------- */
int terminal(int ifd, int ofd, int vflg ) {

  int n, cc, user_ctrl;
  //time_t  stime, ntime;
  //struct  timeval tv;

  //stime = time(0);
  //tv.tv_sec = timeout;
  //tv.tv_usec = 0;
  user_ctrl=0;

  FD_ZERO(&rfd);
  for (;;) {
    FD_SET(ifd, &rfd);
    FD_SET(0, &rfd);
    n = select(ifd+2, &rfd, 0, 0, NULL);//&tv);
    if (n < 0 && errno != EINTR)
      perrx(1, "Fatal select()");

    /* check for task output... */
    if (FD_ISSET(ifd, &rfd)) {
      if ((cc = read(ifd, buf, sizeof(buf)-1)) > 0) {
        buf[cc] = '\0';
        (void)printf("%s", buf);
      }
      else {
        /* Got ERROR */
        if(cc <0){
          if (vflg)
            (void)fprintf(stderr,
                          "%s: Got nothing in output\n",
                          program);
          return 1;
        }
      }
    }
    /* check for user input... */
    if (FD_ISSET(0, &rfd)) {
      if ((cc = read(0, buf+user_ctrl, 1)) > 0) {
        if(user_ctrl){
          if(*(buf+user_ctrl)=='d'){
            /* user press Esc-d. EXIT */
            return 0;
          }
          else{
            if(*(buf+user_ctrl)=='x'){
              /* special sequence! mask it */
              *(buf+user_ctrl+1)='x';
              write(ofd, buf, user_ctrl+2);
            }
            else{
              /* just send it to task */
              write(ofd, buf, user_ctrl+1);
            }
            user_ctrl=0;
          }
        }
        else{
          if(*buf=='\033'){
            /* user press Esc. Remember this */
            user_ctrl=1;
          }
          else{
            /* just send it to task */
            write(ofd, buf, 1);
          }
        }
      }
      else{
        /* NOTHING WAS READ - error or eof */
        if(cc==0){
          /* eof - kill program */
          write(ofd, escape_chars, 3);
          return 0;
        }
      }
    }
  }
  /* never ended */
  return 2;
}

