#!/bin/sh

LIBPATH=/var/lib/cleo-viz
LIBPERM=0644
WWWPERM=0755
DIRPERM=0755

if [ "x$1" = "xrpm" ]; then
  NOINTERACTIVE=1
fi

# Uncomment theese lines and set your paths
#WWWROOT=
#CGIROOT=


if [ "x$WWWGROUP" = "x" ]; then
  WWWGROUP=www-data
fi
if [ "x$WWWUSER" = "x" ]; then
  WWWUSER=www-data
fi

if [ "x$WWWROOT" = "x" ]; then
  if [ -d /var/www/apache2/html ]; then
    # altlinux
    WWWROOT=/var/www/apache2/html
    CGIROOT=/var/www/apache2/cgi-bin

  elif [ -d /var/www/html ]; then

    # redhat/fedora
    WWWROOT=/var/www/html
    CGIROOT=/var/www/cgi-bin

  elif [ -d /var/www/ ]; then
    # debian/ubuntu
    WWWROOT=/var/www
    CGIROOT=/usr/lib/cgi-bin/

  else
    echo "Enter WWW Root directory path:"
    read WWWROOT
    echo "Enter CGI Root directory path:"
    read CGIROOT
  fi

  if [ "x$NOINTERACTIVE" = "x" ]; then
    echo "WWW Root is ${WWWROOT}, CGI Root is ${CGIROOT}. Correct (y/n)?"
    read yn
  else
    yn=y
  fi
else
  yn=y
fi

WWWROOT="$DESTDIR/$WWWROOT"
CGIROOT="$DESTDIR/$CGIROOT"
LIBPATH="$DESTDIR/$LIBPATH"

if [ "z$yn" = "zyes" -o "z$yn" = "zy" ]; then
  # now install!
#  install -g $WWWGROUP -o $WWWUSER -m $DIRPERM -p "$LIBPATH" 
#  install -g $WWWGROUP -o $WWWUSER -m $DIRPERM -p "$WWWROOT/jq"
#  install -g $WWWGROUP -o $WWWUSER -m $DIRPERM -p "$WWWROOT/img"

  install -d -m $DIRPERM "$LIBPATH/"
  install -d -m $DIRPERM "$WWWROOT/"
  install -d -m $DIRPERM "$CGIROOT/"
  install -d -m $DIRPERM "$WWWROOT/img/"
  install -d -m $DIRPERM "$WWWROOT/jq/"

  if [ "x$1" != "xrpm" ]; then
	  chown $WWWGROUP:$WWWUSER "$LIBPATH/"
	  chown $WWWGROUP:$WWWUSER "$WWWROOT/"
	  chown $WWWGROUP:$WWWUSER "$CGIROOT/"
	  chown $WWWGROUP:$WWWUSER "$WWWROOT/img/"
	  chown $WWWGROUP:$WWWUSER "$WWWROOT/jq/"
  fi

  install -D -m $LIBPERM *.tmpl cleo-viz-locale.pm "$LIBPATH/"

  install -D -m $LIBPERM *.png "$WWWROOT/img/"
  install -D -m $LIBPERM *.css "$WWWROOT/"
  install -D -m $LIBPERM jquery-1.4.2.min.js "$WWWROOT/jq/"
  ln -s "jquery-1.4.2.min.js" "$WWWROOT/jq/jq.js"
    
  install -D -m $WWWPERM cleo-viz.cgi "$CGIROOT/"

  if [ "x$1" != "xrpm" ]; then
    chown $WWWGROUP:$WWWUSER $LIBPATH/*
    chown $WWWGROUP:$WWWUSER $WWWROOT/img/*
    chown $WWWGROUP:$WWWUSER $WWWROOT/*
  fi
fi

