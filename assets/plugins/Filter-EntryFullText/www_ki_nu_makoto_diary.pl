# author: poppen
sub handle {
    my ($self, $args) = @_;
    $args->{entry}->link =~ qr!^http://www\.ki\.nu/~makoto/diary/\d{4}/\d{2}/\d{2}/\d+\.html#.*$!;
}
sub extract {
    my ($self, $args) = @_;
    if ($args->{entry}->link =~ m!#(.*)$!) {
        my $fragment = $1;
    if ($args->{content} =~ m|<h3\sclass="new"><a\sclass="hide"\sname="\Q$fragment\E".*?>.*?</a>.*?</h3>.*?<div\sclass="section">(.*?)</div>|is) {
            my $body = $1;
            return "<div>$body</div>";
        }
    }
    return;
}


