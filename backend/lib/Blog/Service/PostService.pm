#----
# perl-vue-blog/backend/lib/Blog/Service/PostService.pm
#----
package Blog::Service::PostService;
use strict;
use warnings;
use utf8;

#use Mojo::Base -strict;
use Blog::Model::PostModel;
use Blog::Entity::Post;

#use MyApp::ToolMy;

sub new {
    #my ($class, $db_path) = @_;
    #return bless { model => Blog::Model::PostModel->new($db_path) }, $class;
    my ($class, %args) = @_;

    my $model = $args{model};
    if (!$model) {
        die "db_path or model is required\n" unless $args{db_path};
        $model = Blog::Model::PostModel->new(db_path => $args{db_path});
    }

    return bless {
        model => $model,
    }, $class;
}

# new 2026.11.22
# 一覧取得（ページング・検索対応）
sub get_posts_paginated {
    my ($self, $page, $per_page, $q) = @_;

    my $raw = $self->{model}->find_paginated($page, $per_page, $q);
    my @entities = map { Blog::Entity::Post->from_hashref($_) } @{ $raw->{posts} || [] };

    return {
        posts        => \@entities,
        total        => $raw->{total},
        total_pages  => $raw->{total_pages},
        current_page => $raw->{current_page},
        q            => $raw->{q},
    };
}

sub get_posts_paginated_old {
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

# new 2026.11.22
# 新規投稿作成（password, email, time_stamp 対応）
sub create_post {
    my ($self, $yname, $title, $content, $password, $email) = @_;

    $yname   = defined $yname   ? _trim("$yname")   : '';
    $title   = defined $title   ? _trim("$title")   : '';
    $content = defined $content ? _trim("$content") : '';
    $password = defined $password ? "$password" : '';
    $email    = defined $email    ? _trim("$email")    : '';

    die "タイトルは必須です\n" if $title eq '';
    die "本文は必須です\n"     if $content eq '';

    my $row = $self->{model}->create({
        yname      => $yname,
        title      => $title,
        content    => $content,
        password   => $password,
        email      => $email,
        time_stamp => time(),
    });

    die "投稿の作成に失敗しました\n" unless $row;
    return Blog::Entity::Post->from_hashref($row);
}

sub create_post_old {
    my ($self, $title, $content) = @_;
    #die "Title is required" unless $title && length($title) > 0;
    #die "Content is required" unless $content && length($content) > 0;
    $self->_validate_post_input($title, $content);
    return $self->{model}->create($title, $content);
}

# new 2026.11.22
# 記事更新（パスワード一致確認あり）
sub update_post {
    my ($self, $id, $yname, $title, $content, $password, $email) = @_;

    die "IDが不正です\n" unless defined $id && $id =~ /^\d+$/;

    my $existing = $self->{model}->find_by_id($id);
    die "対象の記事が見つかりません\n" unless $existing;

    # DB 上の password と照合
    my $input_pw = defined $password ? "$password" : '';
    my $db_pw    = $existing->{password} // '';
    die "パスワードが一致しません\n" unless $db_pw eq $input_pw;

    $yname   = defined $yname   ? _trim("$yname")   : '';
    $title   = defined $title   ? _trim("$title")   : '';
    $content = defined $content ? _trim("$content") : '';
    die "タイトルは必須です\n" if $title eq '';
    die "本文は必須です\n"     if $content eq '';

    my %update_data = (
        title      => $title,
        content    => $content,
        time_stamp => time(),
    );
    if (defined $yname) {
        $update_data{yname} = _trim("$yname");
    }
    if (defined $email) {
        $update_data{email} = _trim("$email");
    }
    # 新しいパスワードが入力されていれば更新（空なら元のまま維持）
    if (defined $password && $password ne '') {
        $update_data{password} = $input_pw;
    }

    my $updated = $self->{model}->update($id, \%update_data);
    die "記事の更新に失敗しました\n" unless $updated;
    return Blog::Entity::Post->from_hashref($updated);
}

sub update_post_old {
    my ($self, $id, $title, $content) = @_;
    die "Invalid post ID" unless defined $id && $id =~ /^\d+$/;
    $self->_validate_post_input($title, $content);

    #die "Title is required" unless defined $title && length($title) > 0;
    #die "Content is required" unless defined $content && length($content) > 0;

    my $post = $self->{model}->update_by_id($id, $title, $content);
    die "Post not found" unless $post;

    return $post;
}

# new 2026.11.22
# 記事削除（パスワード一致確認あり）
sub delete_post {
    my ($self, $id, $password) = @_;

    die "IDが不正です\n" unless defined $id && $id =~ /^\d+$/;

    my $existing = $self->{model}->find_by_id($id);
    die "対象の記事が見つかりません\n" unless $existing;

    my $input_pw = defined $password ? "$password" : '';
    my $db_pw    = $existing->{password} // '';
    die "パスワードが一致しません\n" unless $db_pw eq $input_pw;

    my $ok = $self->{model}->delete($id);
    die "記事の削除に失敗しました\n" unless $ok;

    return 1;
}

sub delete_post_old {
    my ($self, $id) = @_;
    die "Invalid post ID" unless defined $id && $id =~ /^\d+$/;
    my $deleted = $self->{model}->delete_by_id($id);
    die "Post not found" unless $deleted && $deleted > 0;
    return 1;
}

# new 2026.11.22
sub _trim {
    my ($str) = @_;
    $str =~ s/^\s+|\s+$//g;
    return $str;
}

#--- new 2026.11.22 end ---

sub get_all_posts {
    my $self = shift;
    return $self->{model}->find_all();
}



sub _validate_post_input {
    my ($self, $title, $content) = @_;
    die "Title is required"   unless defined $title   && length($title) > 0;
    die "Content is required" unless defined $content && length($content) > 0;
    die "Title is too long"   if length($title) > 100;
    die "Content is too long" if length($content) > 2000;
}






1;
