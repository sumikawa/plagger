package Plagger::Plugin::Publish::Iso_2022_jp_mail;
use strict;
use base qw( Plagger::Plugin );

use DateTime;
use DateTime::Format::Mail;
use Encode;
use Encode::MIME::Header;
use Jcode;
use MIME::Lite;

our %TLSConn;

sub rule_hook { 'publish.entry.fixup' }

sub register {
    my($self, $context) = @_;
    $context->autoload_plugin({ module => "Filter::FormatText" });
    $context->register_hook(
        $self,
        'publish.entry.fixup' => \&notify,
    );
}

sub init {
  my $self = shift;
  $self->SUPER::init(@_);

  $self->conf->{mailto} or Plagger->context->error("mailto is required");
  $self->conf->{mailfrom} ||= 'plagger@localhost';
  print "....\n";
}

sub notify {
  my ($self, $context, $args) = @_;

  return if $args->{feed}->count == 0;

  my $cnf = $self->conf;
  my $now = Plagger::Date->now(timezone => $context->conf->{timezone});
  my $subject = $args->{feed}->title || '(no-title)';
  my $from = $cnf->{mailfrom};

  my $msg = MIME::Lite->new(
    Date     => $now->format('Mail'),
    From     => encode('MIME-Header-ISO_2022_JP', $from),
    To       => encode('MIME-Header-ISO_2022_JP', $cnf->{mailto}),
    Subject  => encode('MIME-Header-ISO_2022_JP', $subject),
    Type     => 'text/plain; charset=ISO-2022-JP',
    Encoding => '7bit',
    Data     => encode_body($args->{entry}->body),
  );

  $msg->send();

  $context->log(info => "Sending $subject to $cnf->{mailto}");
}

sub encode_body {
  my $str = shift;
  $str = remove_utf8_flag($str);
  $str =~ s/\x0D\x0A/\n/g;
  $str =~ tr/\r/\n/;
  return Jcode->new($str, guess_encoding($str))->jis;
}

sub guess_encoding {
  my $str = shift;
  my $enc = Jcode::getcode($str) || 'euc';
  $enc = 'euc' if $enc eq 'ascii' || $enc eq 'binary';
  return $enc;
}

sub remove_utf8_flag { pack 'C0A*', $_[0] }

1;
