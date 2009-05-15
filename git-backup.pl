#!/usr/bin/perl
use MooseX::Declare;

class SinisterCodeBackup {

  has date => (isa => 'Str', is => 'ro', default => localtime);
  has folder => (isa => 'Str', is => 'rw');

  method run {
    chdir $self->folder or
      die "Can't change into directory '", $self->folder, "'.";
    my $folder= $self->folder;
    $self->delete_working_copy_files($self->folders);
    $self->copy_files_to_working_copy($self->folders);
    $self->mysqldump;
    $self->mark_deletes;
    $self->mark_new_files;
    $self->commit_all_changes;
    $self->push_backup;
    $self->mail_push_notice;
  }

  method folders {(
    sites => '/www/dk2/html/sites/*',
    'cjr-html' => '/www/cjr/html/*'
  )}

  method delete_working_copy_files (%folders) {
    for my $folder (keys %folders) {`rm -Rf $folder`}
  }

  method copy_files_to_working_copy (%folders) {
    my ($source, $target);
    for my $folder (keys %folders) {
      `rm -Rf $folder`;
      `mkdir $folder`;
      `cp -RL --no-preserve=mode,ownership $folders{$folder} $folder`;
    }
  }

  method mysqldump {
    my $credentials= "-u root --password=XXXXXXXXX";
    my $options= "-A --create-options";
    `mysqldump $credentials $options >sinistercode-mysql-backup-sql`;
  }

  method mark_deletes {
    for my $file ($self->deleted_files) {`git rm $file`}}

  method deleted_files {
    grep {$_ ne ''}
      map {/^#\s+deleted:\s+([^ ]+)$/; $_= $1; s/^\s+|\s+$//sg; $_}
        grep {/^#\s+deleted:\s+/sg}
          `git status`}

  method mark_new_files {`git add .`}

  method commit_all_changes {
    my $date= localtime;
    `git commit -a -m "Commiting sinistercode backup for $date"`}

  method push_backup {`git push`}

  method mail_push_notice {
    open(MAIL, '| /usr/lib/sendmail -t -oi') or die "Can't send mail.";
    print MAIL
      "To: donnie\@solomonstreet.com\n",
      "From: sinistercode.com <noreply\@sinistercode.com>\n",
      "Subject: Updated sinistercode backup repository\n\n",
      "Captain, Your Highness, Master of the World, Donnie,\n\n",
      "I have updated the sinistercode backup repository with ",
      "the latest changes, according to your excellent program.\n\n",
      "I remain faithfully at your service forever,\n\n",
      "--sinistercode.com\n";
    close MAIL;
  }
}

SinisterCodeBackup->new(folder => "/www/dk2/backup-2/files")->run
