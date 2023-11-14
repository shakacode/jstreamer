# frozen_string_literal: true

namespace :yard do
  desc "Updates and publishes YARD docs"
  task :publish do # rubocop:disable Rails/RakeEnvironment
    abort("\nERROR: Uncommited changes found\n\n") if `git status -s | wc -l`.strip.to_i.positive?

    `git checkout main`
    `git branch -D gh-pages`
    `git checkout -b gh-pages`
    `yard`
    `rm -rf docs`
    `mv doc docs`
    `git add -A`
    `git commit -m 'docs update'`
    `git push -f origin gh-pages`
    `git checkout main`

    # keep clone in my own repo for publishing yard
    `gh repo sync dzirtusss/jstreamer -b main --force`
    `gh repo sync dzirtusss/jstreamer -b gh-pages --force`
  end
end
