package DDGC::Web::Controller::Cronjob;
use Moose;
use namespace::autoclean;

use DDGC::Config;

BEGIN {extends 'Catalyst::Controller'; }

sub base :Chained('/base') :PathPart('cronjob') :CaptureArgs(0) {
    my ( $self, $c ) = @_;
	if (defined $ENV{DDGC_EXECUTE_CRONJOBS}
			&& $ENV{DDGC_EXECUTE_CRONJOBS} eq 'YES'
			&& $c->req->address eq '127.0.0.1') {
		return;
	}
	$c->response->status(403);
	$c->response->body('Not allowed');
	return $c->detach;
}

sub index :Chained('base') :PathPart('') :Args {
    my ( $self, $c, @args ) = @_;
    if ($args[0] eq 'notify_cycle') {
    	$self->notify_cycle($c,$args[1]);
    }
	$c->response->body('OK');
}

my %templates = (
	'comments' => {
		template => 'email/notifications/comments.tx',
		subject => 'New comments on the platform',
	},
	'translations' => {
		template => 'email/notifications/translations.tx',
		subject => 'New translations to vote on in your languages',
	},
	'tokens' => {
		template => 'email/notifications/tokens.tx',
		subject => 'New tokens for translation in your languages',
	},
);

my %mapping = (
	'DDGC::DB::Result::Comment' => 'comments',
	'DDGC::DB::Result::Token' => 'tokens',
	'DDGC::DB::Result::Token::Language::Translation' => 'translations',
);

sub notify_cycle {
	my ( $self, $c, $cycle ) = @_;
	return; # TODO
	my @event_notifications = $c->d->resultset('Event::Notification')->search({
		cycle => $cycle,
		done => 0,
	},{
		join => 'event',
	})->all;
	my %users;
	for (@event_notifications) {
		$users{$_->user->id} = [] unless defined $users{$_->user->id};
		push @{$users{$_->user->id}}, $_;
	}
	for (keys %users) {
		my @notifications = @{$users{$_}};
		my $user = $notifications[0]->user;
		next unless defined $user->data->{email};
		my %store;
		for (@notifications) {
			if (defined $mapping{$_->event->context}) {
				my $type = $mapping{$_->event->context};
				$store{$type} = [] unless defined $store{$type};
				push @{$store{$type}}, $_;
			}
		}
		for (keys %store) {
			my $type = $_;
			my @type_notifications = @{$store{$type}};
			my $text = $self->ddgc->xslate->render($templates{$type}->{template},{
				notifications => \@type_notifications,
				count => (scalar @type_notifications),
				user => $user,
			});
			eval {
				$self->ddgc->postman->mail(
					$user->username.' <'.$user->data->{email}.'>',
					'DuckDuckGo Community Envoy <envoy@dukgo.com>',
					'[DuckDuckGo Community] '.$templates{$type}->{subject},
					$text,
				);
			};
			if ($@) {
				# ... TODO ...
			} else {
				for (@type_notifications) {
					$_->sent(1);
					$_->update;
				}
			}
		}
	}
}

__PACKAGE__->meta->make_immutable;

1;
