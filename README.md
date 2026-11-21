# perl-vue-blog  

Ubuntu 24.04 perl + Vue3 で、Web app サンプル (Blog/Bbs) を作ってみた。  

##### 1. 開発環境の用意。  
i) 必要なパッケージのインストール（Ubuntu 24.04）  
$ sudo apt update  
$ sudo apt install -y sqlite3 libsqlite3-dev cpanminus build-essential nodejs npm  
  
ii) Mojolicious（Perl製Webフレームワーク）のインストール  
注) ユーザディレクトリへ、インストールする。  
~/perl5/ 下のディレクトリーを使う。  
  
$ cpanm Mojolicious  
  
\~/perl5 用の環境変数が未設定の場合は、\~/.bashrc に追記して反映します。  
$ echo 'eval "$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)"' >> ~/.bashrc  
$ source ~/.bashrc  
確認してみる。  
$ mojo version  

##### 2. git clone   
    $ git clone https://github.com/tosa-no-onchan/perl-vue-blog.git  
    $ cd perl-vue-blog/frontend  
    $ npm install  
    $ npm run build  

##### 3. run  
1) Mojolicious Deamon で実行するばあい。
   
    i) backend の起動  
    $ cd perl-vue-blog/backend  
    $ perl app.pl daemon  
    
    ii) frontend の起動  
    そく、実行するなら、下記を行う。  
    $ npm run dev  
    注) frontend/src/App.vue を修正しておく。  
    const use_cgi = 0  

  

