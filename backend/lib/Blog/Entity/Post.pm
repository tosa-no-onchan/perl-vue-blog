#----
# perl-vue-blog/backend/lib/Blog/Entity/Post.pm
#----
package Blog::Entity::Post;
use strict;
use warnings;
use utf8;

#use Mojo::Base -strict;

sub new {
    my ($class, %args) = @_;
    my $self = {
        id         => defined $args{id}         ? int($args{id})         : undef,
        yname      => defined $args{yname}      ? "$args{yname}"          : '',
        title      => defined $args{title}      ? "$args{title}"          : '',
        content    => defined $args{content}    ? "$args{content}"        : '',
        email      => defined $args{email}      ? "$args{email}"          : '',
        time_stamp => defined $args{time_stamp} ? int($args{time_stamp})  : 0,
        created_at => defined $args{created_at} ? "$args{created_at}"      : '',
    };
    return bless $self, $class;
}

# ハッシュリファレンス（DBの行など）から Entity を生成する便利メソッド
sub from_hashref {
    my ($class, $row) = @_;
    return undef unless ref $row eq 'HASH';

    # 意図せず password が渡されても Entity には取り込まない
    return $class->new(
        id         => $row->{id},
        yname      => $row->{yname},
        title      => $row->{title},
        content    => $row->{content},
        email      => $row->{email},
        time_stamp => $row->{time_stamp},
        created_at => $row->{created_at},
    );
}

sub id         { $_[0]->{id} }
sub yname      { $_[0]->{yname} }
sub title      { $_[0]->{title} }
sub content    { $_[0]->{content} }
sub email      { $_[0]->{email} }
sub time_stamp { $_[0]->{time_stamp} }
sub created_at { $_[0]->{created_at} }

# JSON::PP->new->utf8->convert_blessed(1) から自動で呼ばれる
sub TO_JSON {
    my ($self) = @_;
    return {
        id         => defined $self->{id} ? 0 + $self->{id} : undef,
        yname      => $self->{yname},
        title      => $self->{title},
        content    => $self->{content},
        #password => $self->{password},
        email => $self->{email},
        time_stamp => defined $self->{time_stamp} ? int($self->{time_stamp}) : 0,
        created_at => $self->{created_at},
    };
}

1;
