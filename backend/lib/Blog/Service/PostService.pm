#----
# perl-vue-blog/backend/lib/Blog/Service/PostService.pm
#----
package Blog::Service::PostService;
use strict;
use warnings;

#use Mojo::Base -strict;
use Blog::Model::PostModel;
use MyApp::ToolMy;

sub new {
    #my ($class, $db_path) = @_;
    #return bless { model => Blog::Model::PostModel->new($db_path) }, $class;
    my ($class, %args) = @_;

    my $model = $args{model} // Blog::Model::PostModel->new(
        db_path => $args{db_path},
    );
    return bless {
        model => $model,
    }, $class;
}

sub get_all_posts {
    my $self = shift;
    return $self->{model}->find_all();
}

sub get_posts_paginated {
    my ($self, $page, $per_page, $q) = @_;

    #print("PostService::get_posts_paginated() :#1 \n");

    $page = 1 if !$page || $page < 1;
    my $offset = ($page - 1) * $per_page;

    my $keyword = defined $q ? $q : '';
    $keyword =~ s/^\s+|\s+$//g;

    #my $posts = $self->{model}->find_paginated($per_page, $offset, $keyword);
    my $posts = $self->{model}->find_posts_paginated($per_page, $offset, $keyword);

    my $total = $self->{model}->count_all($keyword);
    my $total_pages = int(($total + $per_page - 1) / $per_page);
    $total_pages = 1 if $total_pages == 0;

    return {
        posts       => $posts,
        total       => $total,
        total_pages => $total_pages,
        current_page => $page,
        q            => $keyword,
    };
}

sub _validate_post_input {
    my ($self, $title, $content) = @_;
    die "Title is required"   unless defined $title   && length($title) > 0;
    die "Content is required" unless defined $content && length($content) > 0;
    die "Title is too long"   if length($title) > 100;
    die "Content is too long" if length($content) > 2000;
}

sub create_post {
    my ($self, $title, $content) = @_;
    #die "Title is required" unless $title && length($title) > 0;
    #die "Content is required" unless $content && length($content) > 0;
    $self->_validate_post_input($title, $content);
    return $self->{model}->create($title, $content);
}

sub delete_post {
    my ($self, $id) = @_;
    die "Invalid post ID" unless defined $id && $id =~ /^\d+$/;
    my $deleted = $self->{model}->delete_by_id($id);
    die "Post not found" unless $deleted && $deleted > 0;
    return 1;
}

sub update_post {
    my ($self, $id, $title, $content) = @_;
    die "Invalid post ID" unless defined $id && $id =~ /^\d+$/;
    $self->_validate_post_input($title, $content);

    #die "Title is required" unless defined $title && length($title) > 0;
    #die "Content is required" unless defined $content && length($content) > 0;

    my $post = $self->{model}->update_by_id($id, $title, $content);
    die "Post not found" unless $post;

    return $post;
}


1;
