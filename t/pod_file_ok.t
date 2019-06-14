package main;

use 5.008;

use strict;
use warnings;

use Test::More 0.88;	# Because of done_testing();

# This mess is because if Devel::Hide or Test::Without::Module is
# specified on the command line or in an enclosing file, a straight
# 'use lib qw{ inc/Mock }' would trump it, and the mocked modules would
# still be loaded. With this mess, the command-line version is
# $ perl -Mlib=inc/Mock -MDevel::Hide=HTTP::Tiny ...,
# and the 'use if' sees inc/Mock already in @INC and does not add it
# again.  'use if' is core as of 5.6.2, so I should be OK unless I run
# into some Linux packager who knows better than the Perl Porters what
# should be in core (and yes, they exist).

use constant CODE_REF	=> ref sub {};
use constant NON_REF	=> ref 0;
use constant REGEXP_REF	=> ref qr{};

{
    my $inx = 0;
    OUTER_LOOP: {
	while ( $inx < @INC ) {
	    CODE_REF eq ref $INC[$inx++]
		and last OUTER_LOOP;
	}
	$inx = 0;
    }
    splice @INC, $inx, 0, 'inc/Mock';
}


{
    no warnings qw{ once };

    local $Test::Pod::LinkCheck::Lite::DIRECTORY_LEADER = '_';
    require Test::Pod::LinkCheck::Lite;
}

{
    local $ENV{HOME} = 't/data';

    my $t = Test::Pod::LinkCheck::Lite->new();

    my @rslt;

    $t->pod_file_ok( \'' );

    {
	my $fail;
	TODO: {
	    local $TODO = 'Deliberate failure';
	    $fail = $t->pod_file_ok( 't/data/nonexistent.pod' );
	}
	cmp_ok $fail, '==', 1,
	'Got expected failure checking non-existent file';
    }

    $t->pod_file_ok( 't/data/empty.pod' );

    $t->pod_file_ok( 't/data/no_links.pod' );

    @rslt = $t->pod_file_ok( 't/data/url_links.pod' );
    is_deeply \@rslt, [ 0, 1, 0 ],
	'Test of t/data/url_links.pod returned proper data';

    SKIP: {
	$t->man()
	    or skip 'This system does not support the testing of man links', 1;

	$t->pod_file_ok( 't/data/man.pod' );
    }

    $t->pod_file_ok( 't/data/internal.pod' );

    # This circumlocution will be used for tests where errors are
    # expected.  Unfortunately it only tests that the correct number of
    # errors are reported, not that the errors reported are the correct
    # ones.

    {
	my $errors;

	TODO: {
	    local $TODO = 'Deliberate test failures.';
	    $errors = $t->pod_file_ok( 't/data/internal_error.pod' );
	}

	cmp_ok $errors, '==', 2, 't/data/internal_error.pod had 2 errors';
    }

    $t->pod_file_ok( 't/data/external_builtin.pod' );

    $t->pod_file_ok( 't/data/external_installed.pod' );

    $t->pod_file_ok( 't/data/external_installed_section.pod' );

    {
	my $errors;

	TODO: {
	    local $TODO = 'Deliberate test failures.';
	    $errors = $t->pod_file_ok(
		't/data/external_installed_bad_section.pod' );
	}

	cmp_ok $errors, '==', 1,
	    't/data/external_installed_bad_section.pod had 1 error';
    }

    $t->pod_file_ok( 't/data/external_installed_pod.pod' );

    $t->pod_file_ok( 't/data/external_uninstalled.pod' );

    $t->pod_file_ok( 't/data/bug_leading_format_code.pod' );

    $t->pod_file_ok( 't/data/bug_recursion.pod' );

    $t->all_pod_files_ok();

}

foreach my $check_url ( 0, 1 ) {
    my $t = Test::Pod::LinkCheck::Lite->new(
	check_url	=> $check_url,
    );

    note "Test with explicitly-specified check_url => $check_url";

    if ( $check_url ) {
	$t->pod_file_ok( 't/data/url_links.pod' );
    } else {
	my $errors = $t->pod_file_ok(
	    't/data/url_links.pod' );

	cmp_ok $errors, '==', 0,
	    't/data/url_links.pod error count with url checks disabled';
    }
}

{
    my $code = sub { 0 };

    foreach my $ignore (
	[ []	=> {} ],
	[ undef,	   {} ],
	[ 'http://foo.bar/'	=> {
		NON_REF,	{
		    'http://foo.bar/'	=> 1,
		},
	    },
	],
	[ qr< \Q//foo.bar\E \b >smxi	=> {
		REGEXP_REF,	[
		    qr< \Q//foo.bar\E \b >smxi,
		],
	    },
	],
	[ [ undef, qw< http://foo.bar/ http://baz.burfle/ >, qr|//buzz/| ]	=> {
		NON_REF,	{
		    'http://foo.bar/'	=> 1,
		    'http://baz.burfle/'	=> 1,
		},
		REGEXP_REF,	[
		    qr|//buzz/|,
		],
	    },
	],
	[ [ $code, { 'http://foo/' => 1, 'http://bar/' => 0 } ]	=> {
		NON_REF,	{
		    'http://foo/'	=> 1,
		},
		CODE_REF,	[ $code ],
	    }
	],
    ) {
	my $t = Test::Pod::LinkCheck::Lite->new(
	    ignore_url	=> $ignore->[0],
	);

	is_deeply $t->__ignore_url(), $ignore->[1], join( ' ',
	    'Properly interpreted ignore_url => ',
	    defined $ignore->[0] ? explain $ignore->[0] : 'undef',
	);
    }
}

{
    my $t = Test::Pod::LinkCheck::Lite->new(
	ignore_url	=> qr< \Q//metacpan.org/\E >smx,
    );

    my @rslt = $t->pod_file_ok( 't/data/url_links.pod' );
    is_deeply \@rslt, [ 0, 1, 1 ],
	'Test of t/data/url_links.pod returned proper data when ignoring URL';
}

foreach my $mi ( Test::Pod::LinkCheck::Lite->new()->module_index() ) {

    local $ENV{HOME} = 't/data';

    my $t = Test::Pod::LinkCheck::Lite->new(
	module_index	=> $mi,
    );

    note "Test with module_index => $mi";

    $t->pod_file_ok( 't/data/external_uninstalled.pod' );
}

done_testing;

1;

# ex: set textwidth=72 :
