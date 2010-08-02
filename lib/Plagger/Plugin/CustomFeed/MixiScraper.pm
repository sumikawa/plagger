package Plagger::Plugin::CustomFeed::MixiScraper;
use strict;
use base qw( Plagger::Plugin );

use DateTime::Format::Strptime;
use WWW::Mixi::Scraper;
use Time::HiRes;

our $MAP = {
    FriendDiary => {
        title      => 'マイミク最新日記',
        get_list   => 'new_friend_diary',
        get_detail => 'view_diary',
        icon       => 'owner_id',
    },
    # can't get icon
    Message => {
        title      => 'ミクシィメッセージ受信箱',
        get_list   => 'list_message',
        get_detail => 'view_message',
    },
    # can't get icon
    MessageOutbox => {
        title      => 'ミクシィメッセージ送信済み',
        get_list   => 'list_message',
       get_list_parse_param => { box => 'outbox' },
        get_detail => 'view_message',
    },
    # can't get icon & body
    RecentComment => {
        title      => 'ミクシィ最近のコメント一覧',
        get_list   => 'list_comment',
    },
    Log => {
        title      => 'ミクシィ足跡',
        get_list   => 'show_log',
        icon       => 'id',
    }, 
    MyDiary => {
        title      => 'ミクシィ日記',
        get_list   => 'list_diary',
        get_detail => 'view_diary',
        icon       => 'owner_id',
    },
    Calendar => {
        title      => 'ミクシィカレンダー',
        get_list   => 'show_schedule',
        get_detail => 'view_event',
    },
    BBS => {
        title      => 'コミュニティ最新書き込み',
        get_list   => 'new_bbs',
        get_detail => 'view_bbs',
    },
};

sub plugin_id {
    my $self = shift;
    $self->class_id . '-' . $self->conf->{email};
}

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,
        'subscription.load' => \&load,
    );
}

sub load {
    my($self, $context) = @_;

    my $cookie_jar = $self->cookie_jar;
    if (ref($cookie_jar) ne 'HTTP::Cookies') {
        # using foreign cookies = don't have to set email/password. Fake them
        $self->conf->{email}    ||= 'plagger@localhost';
        $self->conf->{password} ||= 'pl4gg5r';
    }

    $self->{mixi} = WWW::Mixi::Scraper->new(
      email => $self->conf->{email},
      password => $self->conf->{password},
      cookie_jar => $cookie_jar,
      mode => $self->conf->{mode},
    );

    my $feed = Plagger::Feed->new;
       $feed->aggregator(sub { $self->aggregate(@_) });
    $context->subscription->add($feed);
}

sub aggregate {
    my($self, $context, $args) = @_;
    for my $type (@{$self->conf->{feed_type} || ['FriendDiary']}) {
        $context->error("$type not found") unless $MAP->{$type};
        if ($type eq 'BBS' and $self->conf->{split_bbs_feed}) {
            $self->aggregate_bbs_feed($context, $type, $args);
        }
        else {
            $self->aggregate_feed($context, $type, $args);
        }
    }
}

sub aggregate_feed {
    my($self, $context, $type, $args) = @_;

    my $feed = Plagger::Feed->new;
    $feed->type('mixi');
    $feed->title($MAP->{$type}->{title});

    my $meth = $MAP->{$type}->{get_list};
    my $parse_param = $MAP->{$type}->{get_list_parse_param} || {};
    my @msgs = $self->{mixi}->$meth->parse(%$parse_param);
    my $items = $self->conf->{fetch_items} || 20;
    $self->log(info => 'fetch ' . scalar(@msgs) . ' entries');

    $feed->link($self->{mixi}->{mech}->uri);

    my $i = 0;
    $self->{blocked} = 0;
    for my $msg (@msgs) {
        next if $type eq 'FriendDiary' and $msg->{link}->query_param('url'); # external blog
        last if $i++ >= $items;

        $self->add_entry( $context, $type, $feed, $msg );
    }

    $context->update->add($feed);
}

sub aggregate_bbs_feed {
    my($self, $context, $type, $args) = @_;

    my $meth = $MAP->{$type}->{get_list};
    my @msgs = $self->{mixi}->$meth->parse;
    my $items = $self->conf->{fetch_items} || 20;
    $self->log(info => 'fetch ' . scalar(@msgs) . ' entries');

    my $i = 0;
    $self->{blocked} = 0;
    for my $msg (@msgs) {
        next if $type eq 'FriendDiary' and $msg->{link}->query_param('url'); # external blog
        last if $i++ >= $items;

        my $feed = Plagger::Feed->new;
        $feed->type('mixi');
        (my $subject = $msg->{subject}) =~ s/\(\d+\)$//;
        (my $link = $msg->{link}) =~ s/&comment_count=\d*//;
        $feed->title($subject);
        $feed->description($MAP->{$type}->{title}.': '.$msg->{name});
        $feed->link($link);

        $self->add_entry( $context, $type, $feed, $msg );

        $context->update->add($feed);
    }
}

my $format = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d %H:%M');

sub parse_date {
    my ($self, $datetime) = @_;

    # Calendar doesn't have %H:%M part (spotted by id:mad-capone)
    return unless defined $datetime;
    $datetime .= ' 00:00' unless $datetime =~ /\d+:\d+$/;

    Plagger::Date->parse($format, $datetime);
}

sub add_entry {
    my ($self, $context, $type, $feed, $msg) = @_;

    if ($type eq 'Log') {
        $msg->{subject} = $msg->{time} . ' ' . $msg->{name};
    }

    my $entry = Plagger::Entry->new;
    $entry->title($msg->{subject});
    $entry->link($msg->{link});
    $entry->author($msg->{name});
    $entry->date( $self->parse_date($msg->{time}) );
    $entry->date->set_time_zone('Asia/Tokyo') if $entry->date;

    if ($self->conf->{show_icon} && !$self->{blocked} && defined $MAP->{$type}->{icon}) {
        my $owner_id = $msg->{link}->query_param($MAP->{$type}->{icon});
        $context->log(info => "Fetch icon of id=$owner_id");

        my $item = $self->cache->get_callback(
            "outline-$owner_id",
            sub {
                Time::HiRes::sleep( $self->conf->{fetch_body_interval} || 1.5 );
                my $item = $self->{mixi}->show_friend->parse(id => $owner_id)->{outline};
                $item;
            },
            '12 hours',
        );
        if ($item && $item->{image} !~ /no_photo/) {
            # prefer smaller image
            my $image = $item->{image};
               $image =~ s/\.jpg$/s.jpg/;
            $entry->icon({
                title => $item->{name},
                url   => $image,
                link  => $item->{link},
            });
        }
    }

    my @comments;
    if ($self->conf->{fetch_body} && !$self->{blocked} && $msg->{link} =~ /view_/ && defined $MAP->{$type}->{get_detail}) {
        # view_enquete is not implemented and probably
        # won't be implemented as it seems redirected to
        # reply_enquete
        return if $msg->{link} =~ /view_enquete/;
        $context->log(info => "Fetch body from $msg->{link}");
        my $item = $self->cache->get_callback(
            "item-".$msg->{link},
            sub {
                Time::HiRes::sleep( $self->conf->{fetch_body_interval} || 1.5 );
                my $item = $self->{mixi}->parse($msg->{link});
                $item;
            },
            '12 hours',
        );
        if ($item) {
            my $body = $item->{description};
               $body =~ s!(\r\n?|\n)!<br />!g;
            for my $image (@{ $item->{images} || [] }) {
                $body .= qq(<div><a href="$image->{link}"><img src="$image->{thumb_link}" style="border:0" /></a></div>);
                my $enclosure = Plagger::Enclosure->new;
                $enclosure->url($image->{thumb_link});
                $enclosure->auto_set_type;
                $enclosure->is_inline(1);
                $entry->add_enclosure($enclosure);
            }
            $entry->body($body);

            $entry->date( $self->parse_date($item->{time}) );
            $entry->date->set_time_zone('Asia/Tokyo') if $entry->date;
            if ($self->conf->{fetch_comment}) {
              for my $comment (@{ $item->{comments} || [] }) {
                  my $c = Plagger::Entry->new;
                     $c->title($entry->title . ': '. $comment->{subject});
                     $c->body($comment->{description});
                     $c->link($comment->{link});
                     $c->author($comment->{name});
                     $c->date( $self->parse_date($comment->{time}) );
                     $c->date->set_time_zone('Asia/Tokyo') if $c->date;
                  push @comments, $c;
              }
            }
        } else {
            $context->log(warn => "Fetch body failed. You might be blocked?");
            $self->{blocked}++;
        }
    }

    $feed->add_entry($entry);
    for my $comment ( @comments ) {
        $feed->add_entry($comment);
    }
}

1;

__END__

=head1 NAME

Plagger::Plugin::CustomFeed::MixiScraper -  Custom feed for mixi.jp

=head1 SYNOPSIS

    - module: CustomFeed::MixiScraper
      config:
        email: email@example.com
        password: password
        fetch_body: 1
        fetch_comment: 0
        show_icon: 1
        feed_type:
          - RecentComment
          - FriendDiary
          - Message

=head1 DESCRIPTION

This plugin fetches your friends diary updates from mixi
(L<http://mixi.jp/>) and creates a custom feed.

=head1 CONFIGURATION

=over 4

=item email, password

Credential you need to login to mixi.jp.

Note that you don't have to supply email and password if you set
global cookie_jar in your configuration file and the cookie_jar
contains a valid login session there, such as:

  global:
    user_agent:
      cookies: /path/to/cookies.txt

See L<Plagger::Cookies> for details.

=item fetch_body

With this option set, this plugin fetches entry body HTML, not just a
link to the entry. Defaults to 0.

=item fetch_comment

With this option set, this plugin fetches entry's comments as well
(meaningless when C<fetch_body> is not set). Defaults to 0.

=item fetch_body_interval

With C<fetch_body> option set, your Plagger script is recommended to
wait for a little, to avoid mixi.jp throttling. Defaults to 1.5.

=item show_icon: 1

With this option set, this plugin fetches users buddy icon from
mixi.jp site, which makes the output HTML very user-friendly.

=item split_bbs_feed

With this option set, BBS feed will be split up. Defaults to 0.

=item feed_type

With this option set, you can set the feed types.

Now supports: RecentComment, FriendDiary, Message, MessageOutbox, Log, MyDiary, and Calendar.

Default: FriendDiary.

=back

=head1 SCREENSHOT

L<http://blog.bulknews.net/mt/archives/plagger-mixi-icon.gif>

=head1 AUTHOR

Tatsuhiko Miyagawa, modified by Kenichi Ishigaki

=head1 SEE ALSO

L<Plagger>, L<WWW::Mixi::Scraper>

=cut
