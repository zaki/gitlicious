class Project < ActiveRecord::Base

  has_many :metrics
  has_many :reports, :dependent => :destroy
  has_and_belongs_to_many :authors

  before_create :set_name
  after_save :create_authors
  after_create :clone_repository, :create_default_metrics
  after_destroy :remove_repository
  
  accepts_nested_attributes_for :metrics
  
  def update_git_repository
    git.checkout('master', :force => true)
    run('git pull') if git.remotes.size > 0 #Not sure why gem git.pull says "up to date"
  end
    
  def git
    @git ||= Git.open(repo_path)
  end
  
  def problem_count
    reports.size > 0 ? reports.last.problems.count : 0
  end
  
  def current_score
    reports.first.try(:total_score) || 0
  end
  
  def run(command)
    result = ''
    Open4::popen4("sh") do |pid, stdin, stdout, stderr|      
      stdin.puts "unset BUNDLE_GEMFILE"
      stdin.puts "unset RUBYOPT"
      stdin.puts "unset BUNDLE_BIN_PATH"
      stdin.puts "cd #{repo_path}"
      stdin.puts command
      stdin.close
      result = stdout.read.strip
    end
    result
  end
  
  def supports_rcov?
    metrics.exists?(:name => 'rcov')
  end
  
  private
  
  def set_name
    self.name = repo_url[/^.+\/(.+)\.git$/,1]
  end
  
  def create_authors
    run("git log --all --format='author %aN author-mail <%cE>' | sort -u").each_line do |output|
      name = output[/author\s(.+)\sauthor-mail/,1] #CLEANUP: This parsing is similar to the one found in commit.blame
      email = output[/author-mail\s<(.+)>$/,1]
      author = Author.find_or_create_by_name(name,email)
      authors << author unless authors.exists?(author)
    end
  end
  
  def repo_path
    Rails.root.join(Rails.application.config.repo_path, name).to_s
  end
  
  def clone_repository
    Git.clone(repo_url, repo_path) if repo_url?
  end
  
  def remove_repository
    FileUtils.rm_rf(repo_path)
  end
  
  def create_default_metrics
    metrics.create!( :name                 => 'rails_best_practices',
                    :weight               => 0.5,
                    :command              => 'rails_best_practices --without-color .',
                    :score_pattern        => 'Found (\d+) error',
                    :line_number_pattern  => '^.+:(\d+)',
                    :filename_pattern     => '^\.\/(.+):\d',
                    :description_pattern  => '\s-\s(.+)$'
                  )

    metrics.create!( :name                 => 'cleanup',
                    :weight               => 5,
                    :command              => "grep -r -n '#CLEANUP:' app/controllers app/helpers app/models lib",
                    :line_number_pattern  => '^.+:(\d+)',
                    :filename_pattern     => '^(.+):\d',
                    :description_pattern  => '#CLEANUP:\s(.+)$'
                  )

    metrics.create!( :name                 => 'flog',
                    :command              => 'flog -s --continue app/controllers app/helpers app/models lib',
                    :score_pattern        => '([\d\.]+): flog\/method average'
                  )

    # metrics.create!( :name                 => 'rcov',
    #                 :weight               => 2,
    #                 :command              => "bundle exec rcov -Ispec:lib --gcc --rails --exclude osx\/objc,gems\/,spec\/,features\/,seeds\/ --include views -Ispec ./spec/**/*.rb  --only-uncovered --no-html",
    #                 :line_number_pattern  => '^.+:(\d+)',
    #                 :filename_pattern     => '^(.+):\d',
    #                 :description_pattern  => ':\d+:(.+)$'
    #               )
  end
  
end
