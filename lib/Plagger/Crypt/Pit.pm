package Plagger::Crypt::Pit;
use strict;
use Config::Pit;

sub id { 'pit' }

sub decrypt {
	my ($self, $text) = @_;
	my ($domain, $name, $desc) = split "/", $text, 3;
	Plagger->context->log(debug => "Getting password from $domain $name ($desc)");
	pit_get($domain, require => {
		$name => "$desc"
	})->{$name};
}

sub encrypt {
	my ($self, $text) = @_;
	die "Config::Pit encrypt";
}

1;


__END__

=head1 NAME

Plagger::Crypt::Pit - Use Config::Pit to get username and password

=head1 SYNOPSIS

  global:
    encrypt: pit
  plugins:
    - module: Plugin::Foobar
      config:
        username: username
        password: pit::foo/password/password of foo

and, pit config is like followings:

  foo:
    password: *******

CAVEAT: Plagger::Crypt only decrypt password field of plugin's config.
So you should write "username" in plagger config.
