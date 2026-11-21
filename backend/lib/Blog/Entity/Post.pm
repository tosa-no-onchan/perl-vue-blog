#----
# perl-vue-blog/backend/lib/Blog/Entity/Post.pm
#----
package Blog::Entity::Post;
use strict;
use warnings;

#use Mojo::Base -strict;

sub new {
    my ($class, %args) = @_;
    return bless {
        id      => $args{id},
        title   => $args{title},
        content => $args{content},
        created_at => $args{created_at},
    }, $class;
}

sub id {
    my ($self, $val) = @_;
    if (@_ > 1) { $self->{id} = $val; return $self; }
    return $self->{id};
}

sub title {
    my ($self, $val) = @_;
    if (@_ > 1) { $self->{title} = $val; return $self; }
    return $self->{title};
}

sub content {
    my ($self, $val) = @_;
    if (@_ > 1) { $self->{content} = $val; return $self; }
    return $self->{content};
}

sub created_at {
    my ($self, $val) = @_;
    if (@_ > 1) { $self->{created_at} = $val; return $self; }
    return $self->{created_at};
}

# JSON::PP / Mojo::JSON の convert_blessed で呼ばれる
sub TO_JSON {
    my ($self) = @_;
    return {
        id         => defined $self->{id} ? 0 + $self->{id} : undef,
        title      => $self->{title},
        content    => $self->{content},
        created_at => $self->{created_at},
    };
}

1;
