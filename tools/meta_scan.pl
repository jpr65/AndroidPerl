#==============================================================================
#
# meta_scan.pl
#
#      Scan dirs with perl source code for packages and subs,
#      fill this meta information into a PQL::Cache and
#      dump it to file system
#
# Ralf Peine, Mon Apr 27 21:45:17 2015
#
#------------------------------------------------------------------------------
#
# Ideas
#
#------------------------------------------------------------------------------
#
# Use perl5i::Meta on PC (MSWin / Linux) 
#     to extract Meta data from running instances
#
#==============================================================================

use strict;
use vars qw($VERSION);
$VERSION ='0.101';

use v5.10;

use Cwd;
use Data::Dumper;
use FileHandle;
use File::Find;

# local cpan adaptions, currently not released on CPAN, but stored in github
use lib '../spartanic/lib';
use Perl5::Spartanic;

use Report::Porf qw(:all);
use Scalar::Validation qw(:all);
use PQL::Cache qw (:all);
use Perl5::MetaInfo::DB;

# --- handle call args and configuration ----
my $config_file = par configuration => -Default => './android.cfg.pl' => ExistingFile => shift;

require $config_file;

my $config = MyConfig::get();

my $perl_meta_db_file = npar -perl_meta_db_file =>              Filled      => $config;
my $cpan_lib_path     = npar -cpan_lib_path     => -Optional => ExistingDir => $config;
my $perl_lib_path     = npar -perl_lib_path     => -Optional => ExistingDir => $config;

my @paths = map {$_ ? $_:()}  (
    $cpan_lib_path,
    $perl_lib_path,
);

my $meta_perl_info_service = new Perl5::MetaInfo::DB();
my $meta_infos             = $meta_perl_info_service->new_database();

my $next_class_id    = 1;
my $next_method_id   = 1;
my $next_namspace_id = 1;

# --- TODO: Overwork code from cpan -----------
sub extract_perl_version {
        if (
                $_[0] =~ m/
                ^\s*
                (?:use|require) \s*
                v?
                ([\d_\.]+)
                \s* ;
                /ixms
        ) {
                my $perl_version = $1;
                $perl_version =~ s{_}{}g;
                return $perl_version;
        } else {
                return;
        }
}

sub insert_namespace {
    my $namespace = par namespace => Filled => shift;
    
    if ($namespace) {
        my $namespace_known = $meta_infos->select(
            what  => all       =>  
            from  => namespace =>
            where => [ name => $namespace ]
        );
                
        return 1 if (scalar @$namespace_known);
            
        $meta_infos->insert(
            namespace => {
                ID    => $next_namspace_id++, 
                name  => $namespace,
            }
        );
        
        # say "added namespace: $next_namspace_id => $namespace";
    }
    
    return 0;
}
            

sub scan_file {
    my $file = par PerlFile => ExistingFile => shift;
    
    # say "# --- scan $file ---";
    
    my $fh = new FileHandle();
    my $full_file_name = $File::Find::name;
    
    return unless $fh->open($full_file_name);
    
    my $full_class;
    my $current_class_id = 1;
    my $line;
    my $class_meta_info;
    
    $full_file_name =~ s{.*/CCTools/Perl/CPAN/}{{CPAN}/}io;
    while (my $line = <$fh>) {
        $line =~ s/\s+$//o;
        
        last if $line =~ /^\s*__END__$/;
        
        if ($line =~ /^\s*package\s+([\w:]+);/) {
            $full_class = $1;
            # say "class $full_class";
            
            my $namespace  = "";
            my $class_name = $full_class;
            
            if ($full_class =~ /(.*)::(\w+)$/) {
                $namespace  = $1;
                $class_name = $2;
            }
            $current_class_id = $next_class_id++;
            $class_meta_info = {
                    ID        => $current_class_id,
                    fullname  => $full_class,
                    filename  => $full_file_name,
                    namespace => $namespace,
                    classname => $class_name,
                    line_nbr  => $.,
                    line      => $line,
                    subs     => {},
                };
            $meta_infos->insert(class => 
                $class_meta_info
            );
            
            while ($namespace  &&  ! insert_namespace($namespace)) {
                last unless $namespace =~ /::/;
                $namespace =~ s/::\w+$//;
            }
        }
        elsif ($line =~ /^\s*sub\s+(\w+)(.*)/){
            my $sub_name = $1;
            my $sub_rest_of_line = $2;
            
            my $current_method_id = $next_method_id++;
            my $method_meta_info = {
                    ID       => $current_method_id,
                    name     => $sub_name,
                    class_ID => $current_class_id,
                    line_nbr => $.,
                    line     => $line,
                };
                
            $class_meta_info->{subs}->{$sub_name} = $method_meta_info if $class_meta_info;
            $meta_infos->insert(method => 
                $method_meta_info
            );

        # $meta_infos->{$doc_class_name}->{subs}->{$doc_class_method} = {};
        }
    }
    
    # say "# --- done ---";
}

say '';
say '# --- start scan for classes and methods -----------------------';
say '';

$meta_infos->insert(class => {
                        ID        => $next_class_id++,
                        fullname  => 'main',
                        filename  => '',
                        namespace => '',
                        classname => 'main',
                        line_nbr  => '',
                        line      => '',
                        subs     => {},
                }
);

say '# --- dirs to scan recursive ------------------------------------';
say '';

foreach (@paths) { say };

say '';
say '# --- start scan ---';
say '';

find( sub {
    if (-d $_) {
       say "# --- scan dir $_ ---";
    }
    elsif (/\.pm$/i) {
        scan_file($_);
    }
}, @paths);
                
my $class_meta_infos = $meta_infos->select(
                what => all    =>
                from => 'class',
                );

my $method_meta_infos = $meta_infos->select(
                what => all    =>
                from => 'method',
                );

say '# ' . $#$class_meta_infos  . ' classes found.';
say '# ' . $#$method_meta_infos . ' methods found.';

{
    local $Data::Dumper::Purity = 1;
    
    say "# Dump DB into file $perl_meta_db_file ...";
    my $fh = new FileHandle(">$perl_meta_db_file");
    print $fh "package PerlMeta;\nsub load_cache {\n my ";
    print $fh Dumper($meta_infos);
    print $fh 'return $VAR1;'."\n}\n1;\n";
    close $fh;
}
                
say '# === All done. ========================';

1;

__END__

=head1 NAME

meta_scan.pl - Pure perl tool to extract meta data from perl source code

Scan dirs with perl source code for packages and subs,
fill this meta information into a PQL::Cache and
dump it to file system

=head1 VERSION

This documentation refers to version 0.101 of meta_scan.pl

=head1 SYNOPSIS

  meta_scan.pl <config_file.pl>
  
All parameters are defined in the config file, which is a simple Perl file:

  package MyConfig;

  my $root_dir = '/storage/emulated/legacy';

  sub get {
      return {
          -perl_meta_db_file => "$root_dir/perl_sw/info/perl_meta_dump.pl.dump",
          -cpan_lib_path     => "$root_dir/CCTools/Perl/CPAN/lib",
          # -perl_lib_path     => '.',
      };
  }

  1;
  
Create your own config file by copy of android.cfg.pl

=head1 DESCRIPTION

Just create config file and start script. Wait some seconds.

Wait a little longer when parsing your local cpan installation.

Thats all!

=head2 What is extracted

Currently only package name and all subs matching

  /^\s*sub\s+(\w+)/

