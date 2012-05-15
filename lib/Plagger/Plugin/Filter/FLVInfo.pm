package Plagger::Plugin::Filter::FLVInfo;

use strict;
use base qw( Plagger::Plugin );
use Plagger::Util;
use FLV::Info;

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,
        'update.entry.fixup' => \&filter,
    );
}

sub filter {
    my($self, $context, $args) = @_;

    my $entry = $args->{entry};

    # XXX get info from first one only.
    my $enclosure = $entry->enclosure;
    if (!defined $enclosure) {
        $context->log( error => q{Can't find an enclosure.} );
        return;
    }

    eval { $enclosure->local_path };
    if($@){
        $context->log( error => q{Can't get local file.} );
        return;
    }

    my $local_path = $enclosure->local_path;
    if ($local_path !~ m/\.flv$/xmsg) {
        $context->log( warn => qq{Can't get info from $local_path.} );
        return;
    }

    $context->log( info => "Extracting video information from $local_path" );
    my $reader = FLV::Info->new();
    $reader->parse($enclosure->local_path);

    my %info = $reader->get_info;
    my %flvinfo;

    my $height = $info{video_height} || $info{meta_height};
    my $width  = $info{video_width}  || $info{meta_width};

    %flvinfo = (
        height => $height,
        width  => $width,
        aspect => ( $width/$height > 1.5 ) ? '16:9' : '4:3',
    );

    my $metadata_keys = $self->conf->{metadata};
    $metadata_keys = [ $metadata_keys ] unless ref $metadata_keys;
    map { $flvinfo{$_} = $info{$_} } @{$metadata_keys};

    $entry->meta->{flvinfo} = \%flvinfo;
    
}

1;
__END__

=head1 NAME

Plagger::Plugin::Filter::FLVInfo - Add FLV video information to entries

=head1 SYNOPSIS

  - module: Filter::FLVInfo

  - module: Filter::FFmpeg
    rule:
      expression: "$args->{entry}->meta->{flvinfo}->{aspect} eq '4:3'"
    config:
      # Settings for videos whose aspect ratio is '4:3'

  - module: Filter::FFmpeg
    rule:
      expression: "$args->{entry}->meta->{flvinfo}->{aspect} eq '16:9'"
    config:
      # Settings for videos whose aspect ratio is '16:9'

=head1 DESCRIPTION

This plugin extract FLV video information from enclosures, and attach it to the entry.

=head1 CONFIG

  - module: Filter::FLVInfo
    config:
      metadata:
        - duration
        - video_codec
        - audio_rate

=head1 AUTHOR

Yohei Fushii, Masafumi Otsune

=head1 SEE ALSO

L<Plagger>, L<FLV::Info>

=cut
