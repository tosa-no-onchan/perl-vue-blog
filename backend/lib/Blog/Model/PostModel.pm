#----
# perl-vue-blog/backend/lib/Blog/Model/PostModel.pm
#----
package Blog::Model::PostModel;
use strict;
use warnings;

#use Mojo::Base -strict;
use DBI;
use File::Basename qw(dirname);
use File::Path qw(make_path);
use Blog::Entity::Post;

sub new {
    my ($class, %args) = @_;
    my $db_path = $args{db_path} or die "PostModel::new :#1 db_path is required\n";

    my $dir = dirname($db_path);
    make_path($dir) unless -d $dir;

    my $dbh = DBI->connect(
        "dbi:SQLite:dbname=$db_path",
        "",
        "",
        {
            RaiseError     => 1,
            PrintError     => 0,
            AutoCommit     => 1,
            sqlite_unicode => 1,
        }
    ) or die $DBI::errstr;

    my $self = bless {
        db_path => $db_path,
        dbh     => $dbh,
    }, $class;

    $self->_init_table();
    return $self;
}

sub _init_table {
    my ($self) = @_;
    $self->{dbh}->do(q{
        CREATE TABLE IF NOT EXISTS posts (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            title      TEXT NOT NULL,
            content    TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
        )
    });
}

sub _row_to_entity {
    my ($row) = @_;
    return undef unless $row;
    return Blog::Entity::Post->new(
        id         => $row->{id},
        title      => $row->{title},
        content    => $row->{content},
        created_at => $row->{created_at},
    );
}

sub count_posts {
    my ($self, $q) = @_;
    $q //= '';

    if ($q ne '') {
        my $like = '%' . $q . '%';
        my ($cnt) = $self->{dbh}->selectrow_array(
            'SELECT COUNT(*) FROM posts WHERE title LIKE ? OR content LIKE ?',
            undef,
            $like, $like
        );
        return 0 + ($cnt // 0);
    }
    else {
        my ($cnt) = $self->{dbh}->selectrow_array('SELECT COUNT(*) FROM posts');
        return 0 + ($cnt // 0);
    }
}

sub find_posts_paginated {
    my ($self, $limit, $offset, $q) = @_;
    $q //= '';

    my $sth;
    if ($q ne '') {
        my $like = '%' . $q . '%';
        $sth = $self->{dbh}->prepare(
            'SELECT id, title, content, created_at FROM posts '
          . 'WHERE title LIKE ? OR content LIKE ? '
          . 'ORDER BY id DESC LIMIT ? OFFSET ?'
        );
        $sth->execute($like, $like, $limit, $offset);
    }
    else {
        $sth = $self->{dbh}->prepare(
            'SELECT id, title, content, created_at FROM posts '
          . 'ORDER BY id DESC LIMIT ? OFFSET ?'
        );
        $sth->execute($limit, $offset);
    }

    my @posts;
    while (my $row = $sth->fetchrow_hashref()) {
        push @posts, _row_to_entity($row);
    }
    return \@posts;
}

sub find_by_id {
    my ($self, $id) = @_;
    return undef unless defined $id && $id =~ /^\d+$/;

    my $row = $self->{dbh}->selectrow_hashref(
        'SELECT id, title, content, created_at FROM posts WHERE id = ?',
        undef,
        $id
    );
    return _row_to_entity($row);
}

sub insert_post {
    my ($self, $title, $content) = @_;
    $self->{dbh}->do(
        'INSERT INTO posts (title, content) VALUES (?, ?)',
        undef,
        $title, $content
    );
    my $id = $self->{dbh}->last_insert_id(undef, undef, 'posts', undef);
    return $self->find_by_id($id);
}

sub update_post {
    my ($self, $id, $title, $content) = @_;
    return undef unless defined $id && $id =~ /^\d+$/;

    my $sth = $self->{dbh}->prepare(
        'UPDATE posts SET title = ?, content = ? WHERE id = ?'
    );
    my $rows = $sth->execute($title, $content, $id);
    return undef unless defined $rows && $rows > 0;
    return $self->find_by_id($id);
}

sub delete_post {
    my ($self, $id) = @_;
    return 0 unless defined $id && $id =~ /^\d+$/;

    my $sth = $self->{dbh}->prepare('DELETE FROM posts WHERE id = ?');
    my $rows = $sth->execute($id);
    return (defined $rows && $rows > 0) ? 1 : 0;
}


#---- org start ----

# LIKE句用のワイルドカードエスケープ
sub _escape_like {
    my ($self, $str) = @_;
    $str =~ s/\\/\\\\/g;
    $str =~ s/%/\\%/g;
    $str =~ s/_/\\_/g;
    return '%' . $str . '%';
}

sub find_all {
    my $self = shift;
    my $sth = $self->{dbh}->prepare("SELECT id, title, content, created_at FROM posts ORDER BY id DESC");
    $sth->execute();
    
    my @posts;
    while (my $row = $sth->fetchrow_hashref) {
        push @posts, Blog::Entity::Post->new($row);
    }
    return \@posts;
}

# データの総件数を取得（検索キーワード対応）
sub count_all {
    my ($self, $keyword) = @_;
    if (defined $keyword && $keyword ne '') {
        #my $like = '%' . $keyword . '%';
        my $like = $self->_escape_like($keyword);
        my ($count) = $self->{dbh}->selectrow_array(
            "SELECT COUNT(*) FROM posts WHERE title LIKE ? OR content LIKE ?",
            undef,
            $like,
            $like
        );
        return $count // 0;
    }

    my ($row) = $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM posts");
    return $row // 0;
    #my $row = $self->{dbh}->selectrow_arrayref("SELECT COUNT(*) FROM posts");
    #return ($row && defined $row->[0]) ? $row->[0] : 0;
}

# ページネーション対応のデータ取得 (LIMIT / OFFSET)
sub find_paginated {
    my ($self, $limit, $offset, $keyword) = @_;
    my $sth;

    if (defined $keyword && $keyword ne '') {
        #my $like = '%' . $keyword . '%';
        my $like = $self->_escape_like($keyword);
        $sth = $self->{dbh}->prepare(
            "SELECT id, title, content, created_at FROM posts WHERE title LIKE ? OR content LIKE ? ORDER BY id DESC LIMIT ? OFFSET ?"
        );
        $sth->execute($like, $like, $limit, $offset);
    }
    else {
        $sth = $self->{dbh}->prepare(
            "SELECT id, title, content, created_at FROM posts ORDER BY id DESC LIMIT ? OFFSET ?"
        );
        $sth->execute($limit, $offset);
    }
    
    my @posts;
    while (my $row = $sth->fetchrow_hashref) {
        push @posts, Blog::Entity::Post->new($row);
    }
    return \@posts;
}

sub create {
    my ($self, $title, $content) = @_;
    my $sth = $self->{dbh}->prepare("INSERT INTO posts (title, content) VALUES (?, ?)");
    $sth->execute($title, $content);
    my $id = $self->{dbh}->last_insert_id("", "", "posts", "");
    
    # 登録されたレコードを返す
    my $row = $self->{dbh}->selectrow_hashref("SELECT id, title, content, created_at FROM posts WHERE id = ?", undef, $id);
    return Blog::Entity::Post->new($row);
}

# 指定IDの記事を削除（削除された行数を返す）
sub delete_by_id {
    my ($self, $id) = @_;
    my $sth = $self->{dbh}->prepare("DELETE FROM posts WHERE id = ?");
    $sth->execute($id);
    return $sth->rows;
}


# 指定IDの記事を更新（更新後のEntityを返す。見つからない場合は undef）
sub update_by_id {
    my ($self, $id, $title, $content) = @_;
    my $sth = $self->{dbh}->prepare(
        "UPDATE posts SET title = ?, content = ? WHERE id = ?"
    );
    $sth->execute($title, $content, $id);
    return undef unless $sth->rows && $sth->rows > 0;

    my $row = $self->{dbh}->selectrow_hashref(
        "SELECT id, title, content, created_at FROM posts WHERE id = ?",
        undef,
        $id
    );
    return $row ? Blog::Entity::Post->new($row) : undef;
}

1;
