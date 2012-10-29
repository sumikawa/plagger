# author: mizzy
use Plagger::Util qw( decode_content );
use WWW::YouTube::Download;

sub handle {
    my ($self, $url) = @_;
    $url =~ qr!http://(?:(?:au|br|ca|fr|de|us|hk|ie|it|jp|mx|nl|nz|pl|es|tw|gb|www)\.)?youtube\.com/(?:watch(?:\.php)?)?\?v=.+!;
}

sub find {
    my ($self, $args) = @_;
    my $url = $args->{url};

    my $ua = Plagger::UserAgent->new;

    my $res = $ua->fetch($url);
    return if $res->is_error;

        if ((my $verify_url = $res->http_response->request->uri) =~ /\/verify_age\?/) {
            $res = $ua->post($verify_url, { action_confirm => 'Confirm' });
            return if $res->is_error;

            $res = $ua->fetch($url);
            return if $res->is_error;

            $args->{content} = decode_content($res);
        }

    if ($args->{url} =~ /watch\?v=([^&]+)/gms) {
        my $enclosure = Plagger::Enclosure->new;
        my $client = WWW::YouTube::Download->new;
	$enclosure->url($client->playback_url($1, {fmt => 18,}));
        $enclosure->filename("$1." . $client->get_suffix($1));
        $enclosure->type( Plagger::Util::mime_type_of("$1." . $client->get_suffix($1)) );
        return $enclosure;
    }

    return;
}
