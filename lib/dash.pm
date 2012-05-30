#line 1 "dash.pm"
package dash;
use strict;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Data::Dumper;
use Text::CSV;
use Try::Tiny;
use YAML;
use POSIX;

our $VERSION = '0.1';
our @reports;

sub enumeratereports {
    my $reportdir = setting('views') . '/r';
    opendir(DF, $reportdir) || die "No reports found in $reportdir, exiting\n";
    my %allr;
    foreach my $dir (grep { /^[a-z0-9]/i } readdir(DF)) {
	my $d = "$reportdir/$dir";
	my $file = -f "$d/user.yaml" ? "$d/user.yaml" : "$d/meta.yaml";
	if(-f $file) {
	    my $yaml = YAML::LoadFile($file);
	    if(defined $yaml) {
		my $m = $yaml;
		$m->{path} = $dir;
		$allr{$m->{order} . ' ' . $m->{name} . $m->{path}} = $m;
	    } else {
		warning "Unable to parse $file\n";
	    }
	}
    }
    closedir DF;

    my %categories;
    my @catorder;
    foreach my $k (sort keys %allr) {
	my $m = $allr{$k};
	unless(exists $categories{$m->{category}}) {
	    $categories{$m->{category}} = {
		'description' => $m->{category},
		'reports' => [ $m ]
	    };
	    push @catorder, $m->{category};
	} else {
	    push @{$categories{$m->{category}}->{reports}}, $m;
	}
    }
    @reports = ();
    foreach my $cat (@catorder) {
	push @reports, $categories{$cat};
    }
}

sub expandvar($$$ ) {
    my ($var, $varmap, $spin) = @_;
    push(@{ $varmap->{$var} }, ++$$spin);
    return '?';
}

hook 'before' => sub {
    if(!session('user') && request->path_info !~ m{^/login|/js|/css|/images|/img}) {
	var requested_path => request->path_info;
	request->path_info('/login');
    }
};

get '/logout' => sub {
    session->destroy;
    redirect '/';
};

get '/login' => sub {
    if(session('user')) {
	redirect '/';
    }
    my $error = session 'flash' || [];
    session 'flash', [];
    template 'login', { path => vars->{requested_path} ,flash => $error, username => cookie('username') };
};

post '/login' => sub {
    my $sth=database->prepare("select validate_login(?, ?)");
    $sth->execute(params->{username}, params->{password});
    my ($desc) = $sth->fetchrow_array;
    if(defined $desc) {
	session user => params->{username};
	session name => $desc;
	cookie 'username' => params->{username};
    } else {
	push(@{session 'flash'}, { type => 'error', title => 'Login failed', message => 'Bad username or password'});
    }
    redirect params->{path} || '/';
};

hook 'before_template_render' => sub {
    my $tokens = shift;
    my $base = request->base->path;
    $base =~ s/\/+$//g;
    $tokens->{uri_base} = $base;
    $tokens->{categories} = \@reports;
    $tokens->{today} = strftime("%Y-%m-%d", localtime);
};


get '/sql/*' => sub {
    my ($filename) = splat;
    my %varmap; # maps name to integer bind posn
    my %params = params;
    my %ret;
    my @errors;
    try {
	unless(exists $params{sql}) {
	    push @errors, "Query for $filename must contain a sql parameter";
	} else {
	    my $sql = $params{sql};
	    delete $params{sql};
	    my $spin=0;
	    $sql =~ s/\$\(([a-z][a-z0-9]*)\)/expandvar($1, \%varmap, \$spin)/ige;
	    # Deal with cached results here
	    my $dbh = database;
	    unless($dbh) {
		push @errors, "Failed to connect to database: " . $DBI::errstr;
	    } else {
		my $q = $dbh->prepare($sql);
		unless($q) {
		    push @errors, "Failed to prepare query for $filename: $sql: " . database->errstr;
		} else {
		    while(my ($k, $v) = each %varmap) {
			if(exists $params{$k}) {
			    foreach my $i (@$v) {
				$q->bind_param($i, $params{$k});
			    }
			} else {
			    push @errors, "No value passed for parameter $k";
			}
		    }
		    
		    unless(@errors) {
			unless($q->execute) {
			    push @errors, "Failed to execute query for $filename: " . $q->errstr;
			} else {
			    $ret{data} = $q->fetchall_arrayref;
			    $ret{columns} = $q->{NAME};
			}
		    }
		}
	    }
	}
    } catch {
	push @errors, "Problem querying database: $_";
    };
    $ret{errors} = \@errors if @errors;

    $filename =~ /\.json$/ && do {
	content_type('application/json');
	return to_json(\%ret);
    };
    $filename =~ /\.perl$/ && do {
	content_type('text/plain');
	return Dumper(\%ret);
    };
    $filename =~ /\.xml$/ && do {
	content_type('text/xml');
	return to_xml(\%ret);
    };
    $filename =~ /\.csv$/ && do {
	content_type('text/csv');
	header 'Content-Disposition' => "attachment; filename=$filename";
	if(exists $ret{errors}) {
	    return join("\n", @{$ret{errors}}) . "\n";
	}
	my $csv = Text::CSV->new({ binary => 1});
	my @lines;
	$csv->combine(@{$ret{columns}});
	push @lines, $csv->string();
	foreach my $row (@{$ret{data}}) {
	    $csv->combine(@$row);
	    push @lines, $csv->string();
	}
	return join("\n", @lines) . "\n";
    };
    $filename =~ /\.table$/ && do {
	return template 'table', { data => \%ret }, { layout => undef};
    };
    return template 'html', { data => \%ret };    
};

get '/' => sub {
    template 'index';
};

get '/reload' => sub {
    enumeratereports();
    redirect '/';
};

get '/info/diskusage.json' => sub {
    my %paths;
    my %ret;

    my @dbdir = database->selectrow_array("select setting from fetch_path('data_directory')");
    if(@dbdir) {
	$paths{'Main Database Tablespace'} = $dbdir[0];
    }
    my $tbsh = database->prepare("select spcname, spclocation from pg_tablespace where spclocation != ''");
    if(defined $tbsh) {
	if($tbsh->execute()) {
	    while(my ($name, $dir) = $tbsh->fetchrow_array) {
		$paths{"Database Tablespace $name"} = $dir;
	    }
	}
    }
    content_type('application/json');
    $ret{columns} = ['name', 'path', 'filesystem', 'blocks', 'used', 'available', 'capacity', 'mount'];
    $ret{data} = [];

    unless(open IF, '-|', 'df -P') {
	$ret{errors} = [ "Failed to run df: $!" ];
	return to_json(\%ret);
    }

    my @mounts;
    <IF>;
    while(<IF>) {
	chomp;
	my @df = split(/\s+/, $_, 6);
	push @mounts, \@df;
    }
    close IF;
    sort { length($b->[5]) <=> length($a->[5]) } @mounts;

    while(my ($name, $path) = each %paths) {
	if($path =~ /^\//) {
	    foreach my $m (@mounts) {
		if($m->[5] eq substr($path,0,length($m->[5]))) {
		    push @{$ret{data}}, [ $name, $path, @$m ];
		    last;
		}
	    }
	}
    }
    return to_json(\%ret);
};

hook 'database_error' => sub {
    debug "Database error:", $DBI::errstr;
};

enumeratereports();

true;
