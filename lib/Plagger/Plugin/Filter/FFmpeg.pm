package Plagger::Plugin::Filter::FFmpeg;

use strict;
use base qw( Plagger::Plugin );
use Plagger::Util;
use Encode;
use File::Spec;
use FFmpeg::Command;
use File::stat;

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

    my $ext = $self->conf->{ext} || 'm4v';
    $context->log( warn => 'ext option is ignored because you set filename option' )
        if $self->conf->{ext} and $self->conf->{filename};

    my $enclosures = $entry->enclosures;
    $context->log( warn => 'You shuld not use filename option because the entry has several enclosures.' )
        if $#{$enclosures} > 1;

    for my $enclosure ( @$enclosures ){
        eval { $enclosure->local_path };
        if($@){
            $context->log(error => q{Can't get local file.} );
            return;
        }

        my $file;
        if ($self->conf->{filename}) {
            $file = Plagger::Util::filename_for($entry, $self->conf->{filename});
        } else {
            $file = $enclosure->filename;
            $file =~ s/\.[^\.]*$//;
            $file .= ".$ext";
        }

        my $ff = FFmpeg::Command->new($self->conf->{command});
        $ff->input_options({ file =>  $self->convert($enclosure->local_path) });

        my $output_file = File::Spec->catfile($self->conf->{dir}, "$file");
        my $output_options = {
            file    => $self->convert($output_file),
            device  => $self->conf->{device} || 'ipod',
            title   => $self->convert($entry->title),
            author  => $self->convert($entry->author),
            comment => $self->convert($entry->summary),
            %{ $self->conf->{options} || {} },
        };

        if ( $self->conf->{extra_options} ) {
            my %option_to_name = reverse %FFmpeg::Command::option;
            my @extra_options =  split ' ', $self->conf->{extra_options};
            for ( @extra_options ){
                my $name = $option_to_name{$_};
                delete $output_options->{$name} if defined $output_options->{$name} and $name;
            }
            $ff->output_options($output_options);
            $ff->options( @extra_options, @{ $ff->options } );
        }
        else {
            $ff->output_options($output_options);
        }

        unless( -e $output_file ){
            $context->log( info => 'Converting ' . $enclosure->filename . ' ...' );
            my $result = $ff->exec();
            unless ( $result ){
                $context->log( error => $ff->errstr );
                return;
            }
        }

        my $st = stat($output_file);
        $enclosure->length($st->size);
        $enclosure->local_path($output_file);
        $enclosure->filename("$file");
        $enclosure->type( Plagger::Util::mime_type_of($file) );
    }
}


sub convert {
  my ($self, $str) = @_;
  utf8::decode($str) unless utf8::is_utf8($str);
  return encode($self->conf->{encoding} || 'cp932', $str);
}

1;
__END__

=head1 NAME

Plagger::Plugin::Filter::FFmpeg - Convert enclosure file with ffmpeg command.

=head1 SYNOPSIS

  # Convert video file into iPod playable format.
  - module: Filter::FFmpeg
    config:
      dir: /home/miya/mov

  # Convert video file into PSP playable format.
  - module: Filter::FFmpeg
    config:
      dir: /home/miya/mov
      device: psp

  # Convert video file into your favorite format.
  - module: Filter::FFmpeg
    config:
      dir: /home/miya/mov
      ext: m4v
      command: /usr/local/bin/ffmpeg
      encoding: cp932
      filename: %t.m4v
      options:
        format:              psp
        video_codec:         h264
        bitrate:             600
        frame_size:          320x240
        audio_codec:         aac
        audio_sampling_rate: 48000
        audio_bit_rate:      64
      extra_options: -coder 0 -vlevel 13 -ac 2

=head1 DESCRIPTION

This plugin converts enclosure into iPod playable format, PSP playable format and other formats you lie with ffmpeg command.

=head1 CONFIG

=head2 dir

Specify the directory name that converted files put in.

=head2 ext

Specify a file extension of converted enclosure file.
Default is 'm4v.'

=head2 filename

Set a filename of converted files.If this option is null, this plugin uses enclosure->filename and ext option to compose the filename of converted file.

If this option is set, ext option is ignored.

=head2 command

Specify ffmpeg command path.
You need to set this parameter if ffmpeg command is not in PATH envoiroment variable.

=head2 device

For which device you'd like to convert enclosure files.
You can chooe 'ipod' or 'psp.' Default is 'ipod.'

=head2 encoding

Character encoding of title, author and comment. Default value is cp932.

=head2 options

You can specify output video format as you like.

Available options are:

=over

=item format

Output video format.

=item video_codec

Output video codec.

=item bitrate

Output video bitrate.

=item frame_size

Output video screen size.

=item audio_codec

Output audio code.

=item audio_sampling_rate

Output audio sampling rate.

=item audio_bit_rate

Output audio bit rate.

=back

=head2 extra_options

Extra raw options passed to ffmpeg command.

=head1 AUTHOR

Gosuke Miyashita

=head1 SEE ALSO

L<Plagger>, L<FFmpeg::Command>

=cut
