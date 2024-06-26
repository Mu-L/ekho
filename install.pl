#!/usr/bin/perl

use strict;
use warnings;

our ($lang, $skip_build) = @ARGV;

sub kill_speechd() {
  if (`ps -ef | grep orca | grep -v grep`) {
    `ps -ef | grep orca | grep -v grep | awk '{ print \$2 }' | xargs sudo kill -9`;
  }
  if (`ps -ef | grep speechd.sock | grep -v grep`) {
    `ps -ef | grep speechd.sock | grep -v grep | awk '{ print \$2 }' | xargs sudo kill -9`;
  }
  if (`ps -ef | grep speech-dispatcher | grep -v grep`) {
    `ps -ef | grep speech-dispatcher | grep -v grep | awk '{ print \$2 }' | xargs sudo kill -9`;
  }
  if (`ps -ef | grep sd_ekho | grep -v grep`) {
    `ps -ef | grep sd_ekho | grep -v grep | awk '{ print \$2 }' | xargs sudo kill -9`;
  }
}

sub build_common() {
  system('sudo apt-get -y install libsndfile1-dev');
  system('sudo apt-get -y install libespeak-ng-dev');
  system('sudo apt-get -y install libpulse-dev');
  system('sudo apt-get -y install libncurses5-dev');
  system('sudo apt-get -y install build-essential');
  system('sudo apt-get -y install autoconf automake libtool');
  system('sudo apt-get -y install libdotconf-dev');
  system('sudo apt-get -y install libmp3lame-dev');
  system('sudo apt-get -y install libmpg123-dev libsonic-dev libutfcpp-dev');
  system('sudo apt-get -y install libestools2.1-dev');
  system('sudo apt-get -y install gettext');
  system('sudo apt-get -y install texinfo');
  system('sudo apt-get -y install libltdl-dev');
#  system('./configure --enable-festival --enable-speechd');
  system('./configure --enable-speechd');
  system('make clean && make CXXFLAGS=-O0');
}

sub setup_common() {
  my $t = time();
  system('sudo cp /etc/speech-dispatcher/speechd.conf /etc/speech-dispatcher/speechd.conf.' . $t);
  `grep -v 'sd_ekho' /etc/speech-dispatcher/speechd.conf.$t | grep -v ekho.conf | sed -e 's/^DefaultModule.*/DefaultModule ekho/'>/tmp/speechd.conf.ekho`;
  `echo 'AddModule "ekho" "sd_ekho" "ekho.conf"' >>/tmp/speechd.conf.ekho`;
  `sudo mv /tmp/speechd.conf.ekho /etc/speech-dispatcher/speechd.conf`;

  my $config = '/usr/lib/python3/dist-packages/speechd_config/config.py';
  #if (-e '/usr/share/pyshared/speechd_config/config.py') {
    # older than 14.04
  #  $config = '/usr/share/pyshared/speechd_config/config.py';
  #}

  if (-e $config) {
    `sudo cp $config $config.$t`;
    `cat $config.$t | sed -e 's/"espeak", /"espeak", "ekho", /' | sed -e 's/"ekho", "ekho", /"ekho", /' > /tmp/config.py.ekho`;
    `sudo mv /tmp/config.py.ekho $config`;
  }
}

sub setup_lang() {
  if (not `grep $lang /etc/speech-dispatcher/speechd.conf`) {
    `echo 'DefaultLanguage "$lang"' | sudo tee -a /etc/speech-dispatcher/speechd.conf`;
    `echo 'LanguageDefaultModule "$lang" "ekho"' | sudo tee -a /etc/speech-dispatcher/speechd.conf`;
  }

  if (-f ($ENV{HOME} . "/.speech-dispatcher/conf/speechd.conf") &&
      not `grep $lang ~/.speech-dispatcher/conf/speechd.conf`) {
    `echo 'DefaultLanguage "$lang"' >>~/.speech-dispatcher/conf/speechd.conf`;
    `echo 'LanguageDefaultModule "$lang"  "ekho"' >>~/.speech-dispatcher/conf/speechd.conf`;
  }

  # for 14.04
  if (-f ($ENV{HOME} . "/.config/speech-dispatcher/speechd.conf") &&
      not `grep $lang ~/.config/speech-dispatcher/speechd.conf`) {
    `echo 'DefaultLanguage "$lang"' >>~/.config/speech-dispatcher/speechd.conf`;
    `echo 'LanguageDefaultModule "$lang"  "ekho"' >>~/.config/speech-dispatcher/speechd.conf`;
  } elsif (-d ($ENV{HOME} . "/.config/speech-dispatcher")) {
    `sudo chown -R $ENV{USER} $ENV{HOME}/.config/speech-dispatcher`;
    `cp /etc/speech-dispatcher/speechd.conf $ENV{HOME}/.config/speech-dispatcher/`;
  }

  `perl -0777 -pi.original -e 's/"speechServerInfo": \[[^\]]+\]/"speechServerInfo": \["ekho","ekho"\]/igs' $ENV{HOME}/.local/share/orca/user-settings.conf`;
  `perl -0777 -pi.original -e 's/"family": {\\s*"name": "[^"]+"/"family": { "name": "ekho"/igs' $ENV{HOME}/.local/share/orca/user-settings.conf`;
}

##### main #####
if (not $lang) {
  $lang = 'Mandarin';
}
if ($lang ne 'Tibetan' and $lang ne 'Mandarin' and $lang ne 'Cantonese') {
  print "Only Mandarin, Cantonese and Tibetan are supported. Fallback to Mandarin\n";
  $lang = 'Mandarin';
}

my $os = `lsb_release -i`;
if ($os !~ /Ubuntu/ && $os !~ /Debian/) {
  print "Sorry. Your OS is not supported. Please refer to INSTALL. You can also send email to Cameron <hgneng at gmail.com> for help.\n";  
} else {
  build_common() if (not $skip_build);
  setup_common();
  kill_speechd();
  system('sudo rm -rf /usr/local/share/ekho-data');
  system('sudo make install');
  setup_lang();
}

# start/restart Orca
print "restarting Orca\n";
`killall speech-dispatcher`;
`sleep 3`;
system("orca --replace &");
