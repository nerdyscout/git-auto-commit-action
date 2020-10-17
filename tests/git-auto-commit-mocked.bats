#!/usr/bin/env bats

setup() {
    . shellmock

    # Build World
    export test_repository="${BATS_TEST_DIRNAME}/test_repo"

    rm -rf "${test_repository}"
    mkdir "${test_repository}"
    touch "${test_repository}"/{a,b,c}.txt
    cd "${test_repository}"

    git init --quiet
    git add . > /dev/null 2>&1

    if [[ -z $(git config user.name) ]]; then
        git config --global user.email "test@github.com"
        git config --global user.name "Test Suite"
    fi

    git commit --quiet -m "Init Repo"

    # Set default INPUT variables
    export INPUT_REPOSITORY="${BATS_TEST_DIRNAME}/test_repo"
    export INPUT_COMMIT_MESSAGE="Commit Message"
    export INPUT_BRANCH="master"
    export INPUT_COMMIT_OPTIONS=""
    export INPUT_FILE_PATTERN="."
    export INPUT_COMMIT_USER_NAME="Test Suite"
    export INPUT_COMMIT_USER_EMAIL="test@github.com"
    export INPUT_COMMIT_AUTHOR="Test Suite <test@users.noreply.github.com>"
    export INPUT_TAGGING_MESSAGE=""
    export INPUT_PUSH_OPTIONS=""
    export INPUT_CHECKOUT_OPTIONS=""
    export INPUT_SKIP_DIRTY_CHECK=false

    skipIfNot "$BATS_TEST_DESCRIPTION"

    if [ -z "$TEST_FUNCTION" ]; then
        shellmock_clean
    fi
}

teardown() {

    if [ -z "$TEST_FUNCTION" ]; then
        shellmock_clean
    fi

    rm -rf "${test_repository}"
}

main() {
    bash "${BATS_TEST_DIRNAME}"/../entrypoint.sh
}


@test "clean-repo-prints-nothing-to-commit-message" {

    run main

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "INPUT_REPOSITORY value: ${INPUT_REPOSITORY}" ]
    [ "${lines[1]}" = "::set-output name=changes_detected::false" ]
    [ "${lines[2]}" = "Working tree clean. Nothing to commit." ]
}

@test "commit-changed-files-and-push-to-remote" {

    touch "${test_repository}"/new-file-{1,2,3}.txt

    shellmock_expect git --type partial --output " M new-file-1.txt M new-file-2.txt M new-file-3.txt" --match "status"
    shellmock_expect git --type exact --match "fetch"
    shellmock_expect git --type exact --match "checkout master --"
    shellmock_expect git --type partial --match "add ."
    shellmock_expect git --type partial --match '-c'
    shellmock_expect git --type partial --match 'push --set-upstream origin'

    run main

    echo "$output"

    # Success Exit Code
    [ "$status" = 0 ]

    [ "${lines[0]}" = "INPUT_REPOSITORY value: ${INPUT_REPOSITORY}" ]
    [ "${lines[1]}" = "::set-output name=changes_detected::true" ]
    [ "${lines[2]}" = "INPUT_BRANCH value: master" ]
    [ "${lines[3]}" = "INPUT_FILE_PATTERN: ." ]
    [ "${lines[4]}" = "INPUT_COMMIT_OPTIONS: " ]
    [ "${lines[5]}" = "::debug::Apply commit options " ]
    [ "${lines[6]}" = "INPUT_TAGGING_MESSAGE: " ]
    [ "${lines[7]}" = "No tagging message supplied. No tag will be added." ]
    [ "${lines[8]}" = "INPUT_PUSH_OPTIONS: " ]
    [ "${lines[9]}" = "::debug::Apply push options " ]
    [ "${lines[10]}" = "::debug::Push commit to remote branch master" ]


    shellmock_verify
    [ "${capture[0]}" = "git-stub status -s -- ." ]
    [ "${capture[1]}" = "git-stub fetch" ]
    [ "${capture[2]}" = "git-stub checkout master --" ]
    [ "${capture[3]}" = "git-stub add ." ]
    # [ "${capture[4]}" = "git-stub -c user.name=Test Suite -c user.email=test@github.com commit -m Commit Message --author=Test Suite <test@users.noreply.github.com>" ]
    [ "${capture[5]}" = "git-stub push --set-upstream origin HEAD:master --tags" ]
}

@test "skip-dirty-on-clean-repo-failure" {

    INPUT_SKIP_DIRTY_CHECK=true

    shellmock_expect git --type exact --match "status -s ."
    shellmock_expect git --type exact --match "fetch"
    shellmock_expect git --type exact --match "checkout master --"
    shellmock_expect git --type exact --match "add ."
    shellmock_expect git --type partial --match '-c'
    shellmock_expect git --type partial --match 'push origin'

    run main

    echo "$output"

    shellmock_verify
    [ "${capture[0]}" = "git-stub status -s -- ." ]
    [ "${capture[1]}" = "git-stub fetch" ]
    [ "${capture[2]}" = "git-stub checkout master --" ]
    [ "${capture[3]}" = "git-stub add ." ]
    # [ "${capture[4]}" = "git-stub -c user.name=Test Suite -c user.email=test@github.com commit -m Commit Message --author=Test Suite <test@users.noreply.github.com>" ]
    [ "${capture[5]}" = "git-stub push --set-upstream origin HEAD:master --tags" ]

    # Failed Exit Code
    [ "$status" -ne 0 ]

    [ "${lines[0]}" = "INPUT_REPOSITORY value: ${INPUT_REPOSITORY}" ]
    [ "${lines[1]}" = "::set-output name=changes_detected::true" ]
    [ "${lines[2]}" = "INPUT_BRANCH value: master" ]
    [ "${lines[3]}" = "INPUT_FILE_PATTERN: ." ]
    [ "${lines[4]}" = "INPUT_COMMIT_OPTIONS: " ]
    [ "${lines[5]}" = "::debug::Apply commit options " ]
}

@test "git-add-file-pattern-is-applied" {

    INPUT_FILE_PATTERN="*.txt *.html"

    touch "${test_repository}"/new-file-{1,2}.php
    touch "${test_repository}"/new-file-{1,2}.html

    shellmock_expect git --type partial --output " M new-file-1.html M new-file-2.html" --match "status"
    shellmock_expect git --type exact --match "fetch"
    shellmock_expect git --type exact --match "checkout master --"
    shellmock_expect git --type partial --match "add"
    shellmock_expect git --type partial --match '-c'
    shellmock_expect git --type partial --match 'push --set-upstream origin'

    run main

    echo "$output"

    # Success Exit Code
    [ "$status" = 0 ]

    [ "${lines[3]}" = "INPUT_FILE_PATTERN: *.txt *.html" ]
    [ "${lines[10]}" = "::debug::Push commit to remote branch master" ]


    shellmock_verify
    [ "${capture[0]}" = "git-stub status -s -- a.txt b.txt c.txt new-file-1.html new-file-2.html" ]
    [ "${capture[1]}" = "git-stub fetch" ]
    [ "${capture[2]}" = "git-stub checkout master --" ]
    [ "${capture[3]}" = "git-stub add a.txt b.txt c.txt new-file-1.html new-file-2.html" ]
    # [ "${capture[4]}" = "git-stub -c user.name=Test Suite -c user.email=test@github.com commit -m Commit Message --author=Test Suite <test@users.noreply.github.com>" ]
    [ "${capture[5]}" = "git-stub push --set-upstream origin HEAD:master --tags" ]
}

@test "git-commit-options-are-applied" {

    INPUT_COMMIT_OPTIONS="--no-verify --signoff"

    touch "${test_repository}"/new-file-{1,2}.txt

    shellmock_expect git --type partial --output " M new-file-1.txt M new-file-2.txt" --match "status"
    shellmock_expect git --type exact --match "fetch"
    shellmock_expect git --type exact --match "checkout master --"
    shellmock_expect git --type partial --match "add"
    shellmock_expect git --type partial --match '-c'
    shellmock_expect git --type partial --match 'push --set-upstream origin'

    run main

    echo "$output"

    # Success Exit Code
    [ "$status" = 0 ]
    [ "${lines[4]}" = "INPUT_COMMIT_OPTIONS: --no-verify --signoff" ]
    [ "${lines[10]}" = "::debug::Push commit to remote branch master" ]

    shellmock_verify
    [ "${capture[0]}" = "git-stub status -s -- ." ]
    [ "${capture[1]}" = "git-stub fetch" ]
    [ "${capture[2]}" = "git-stub checkout master --" ]
    [ "${capture[3]}" = "git-stub add ." ]
    # [ "${capture[4]}" = "git-stub -c user.name=Test Suite -c user.email=test@github.com commit -m Commit Message --author=Test Suite <test@users.noreply.github.com> --no-verify --signoff" ]
    [ "${capture[5]}" = "git-stub push --set-upstream origin HEAD:master --tags" ]
}

@test "commit-user-and-author-settings-are-applied" {

    INPUT_COMMIT_USER_NAME="A Single Test"
    INPUT_COMMIT_USER_EMAIL="single-test@github.com"
    INPUT_COMMIT_AUTHOR="A Single Test <single@users.noreply.github.com>"

    touch "${test_repository}"/new-file-{1,2}.txt

    shellmock_expect git --type partial --output " M new-file-1.txt M new-file-2.txt" --match "status"
    shellmock_expect git --type exact --match "fetch"
    shellmock_expect git --type exact --match "checkout master --"
    shellmock_expect git --type partial --match "add"
    shellmock_expect git --type partial --match '-c'
    shellmock_expect git --type partial --match 'push --set-upstream origin'

    run main

    echo "$output"

    # Success Exit Code
    [ "$status" = 0 ]

    [ "${lines[10]}" = "::debug::Push commit to remote branch master" ]

    shellmock_verify
    [ "${capture[0]}" = "git-stub status -s -- ." ]
    [ "${capture[1]}" = "git-stub fetch" ]
    [ "${capture[2]}" = "git-stub checkout master --" ]
    [ "${capture[3]}" = "git-stub add ." ]
    # [ "${capture[4]}" = "git-stub -c user.name=A Single Test -c user.email=single-test@github.com commit -m Commit Message --author=A Single Test <single@users.noreply.github.com>" ]
    [ "${capture[5]}" = "git-stub push --set-upstream origin HEAD:master --tags" ]
}

@test "can-create-tag" {

    INPUT_TAGGING_MESSAGE="v1.0.0"

    touch "${test_repository}"/new-file-{1,2,3}.txt

    shellmock_expect git --type partial --output " M new-file-1.txt M new-file-2.txt M new-file-3.txt" --match "status"
    shellmock_expect git --type exact --match "fetch"
    shellmock_expect git --type exact --match "checkout master --"
    shellmock_expect git --type partial --match "add ."
    shellmock_expect git --type partial --match '-c'
    shellmock_expect git --type partial --match 'push --set-upstream origin'

    run main

    echo "$output"

    # Success Exit Code
    [ "$status" = 0 ]

    [ "${lines[6]}" = "INPUT_TAGGING_MESSAGE: v1.0.0" ]
    [ "${lines[7]}" = "::debug::Create tag v1.0.0" ]
    [ "${lines[10]}" = "::debug::Push commit to remote branch master" ]


    shellmock_verify
    [ "${capture[0]}" = "git-stub status -s -- ." ]
    [ "${capture[1]}" = "git-stub fetch" ]
    [ "${capture[2]}" = "git-stub checkout master --" ]
    [ "${capture[3]}" = "git-stub add ." ]
    # [ "${capture[4]}" = "git-stub -c user.name=Test Suite -c user.email=test@github.com commit -m Commit Message --author=Test Suite <test@users.noreply.github.com>" ]
    [ "${capture[5]}" = "git-stub -c user.name=Test Suite -c user.email=test@github.com tag -a v1.0.0 -m v1.0.0" ]
    [ "${capture[6]}" = "git-stub push --set-upstream origin HEAD:master --tags" ]

}

@test "git-push-options-are-applied" {

    INPUT_PUSH_OPTIONS="--force"

    touch "${test_repository}"/new-file-{1,2,3}.txt

    shellmock_expect git --type partial --output " M new-file-1.txt M new-file-2.txt M new-file-3.txt" --match "status"
    shellmock_expect git --type exact --match "fetch"
    shellmock_expect git --type exact --match "checkout master --"
    shellmock_expect git --type partial --match "add ."
    shellmock_expect git --type partial --match '-c'
    shellmock_expect git --type partial --match 'push --set-upstream origin'

    run main

    echo "$output"

    # Success Exit Code
    [ "$status" = 0 ]

    [ "${lines[8]}" = "INPUT_PUSH_OPTIONS: --force" ]
    [ "${lines[9]}" = "::debug::Apply push options --force" ]
    [ "${lines[10]}" = "::debug::Push commit to remote branch master" ]


    shellmock_verify
    [ "${capture[0]}" = "git-stub status -s -- ." ]
    [ "${capture[1]}" = "git-stub fetch" ]
    [ "${capture[2]}" = "git-stub checkout master --" ]
    [ "${capture[3]}" = "git-stub add ." ]
    # [ "${capture[4]}" = "git-stub -c user.name=Test Suite -c user.email=test@github.com commit -m Commit Message --author=Test Suite <test@users.noreply.github.com>" ]
    [ "${capture[5]}" = "git-stub push --set-upstream origin HEAD:master --tags --force" ]

}

@test "git-checkout-options-are-applied" {

    INPUT_CHECKOUT_OPTIONS="-b --progress"

    touch "${test_repository}"/new-file-{1,2,3}.txt

    shellmock_expect git --type partial --output " M new-file-1.txt M new-file-2.txt M new-file-3.txt" --match "status"
    shellmock_expect git --type exact --match "fetch"
    shellmock_expect git --type exact --match "checkout -b --progress master --"
    shellmock_expect git --type partial --match "add ."
    shellmock_expect git --type partial --match '-c'
    shellmock_expect git --type partial --match 'push --set-upstream origin'

    run main

    echo "$output"

    # Success Exit Code
    [ "$status" = 0 ]

    [ "${lines[10]}" = "::debug::Push commit to remote branch master" ]


    shellmock_verify
    [ "${capture[0]}" = "git-stub status -s -- ." ]
    [ "${capture[1]}" = "git-stub fetch" ]
    [ "${capture[2]}" = "git-stub checkout -b --progress master --" ]
    [ "${capture[3]}" = "git-stub add ." ]
    # [ "${capture[4]}" = "git-stub -c user.name=Test Suite -c user.email=test@github.com commit -m Commit Message --author=Test Suite <test@users.noreply.github.com>" ]
    [ "${capture[5]}" = "git-stub push --set-upstream origin HEAD:master --tags" ]

}

@test "can-checkout-different-branch" {

    INPUT_BRANCH="foo"

    touch "${test_repository}"/new-file-{1,2,3}.txt

    shellmock_expect git --type partial --output " M new-file-1.txt M new-file-2.txt M new-file-3.txt" --match "status"
    shellmock_expect git --type exact --match "fetch"
    shellmock_expect git --type exact --match "checkout foo --"
    shellmock_expect git --type partial --match "add ."
    shellmock_expect git --type partial --match '-c'
    shellmock_expect git --type partial --match 'push --set-upstream origin'

    run main

    echo "$output"

    # Success Exit Code
    [ "$status" = 0 ]

    [ "${lines[0]}" = "INPUT_REPOSITORY value: ${INPUT_REPOSITORY}" ]
    [ "${lines[1]}" = "::set-output name=changes_detected::true" ]
    [ "${lines[2]}" = "INPUT_BRANCH value: foo" ]
    [ "${lines[3]}" = "INPUT_FILE_PATTERN: ." ]
    [ "${lines[4]}" = "INPUT_COMMIT_OPTIONS: " ]
    [ "${lines[5]}" = "::debug::Apply commit options " ]
    [ "${lines[6]}" = "INPUT_TAGGING_MESSAGE: " ]
    [ "${lines[7]}" = "No tagging message supplied. No tag will be added." ]
    [ "${lines[8]}" = "INPUT_PUSH_OPTIONS: " ]
    [ "${lines[9]}" = "::debug::Apply push options " ]
    [ "${lines[10]}" = "::debug::Push commit to remote branch foo" ]


    shellmock_verify
    [ "${capture[0]}" = "git-stub status -s -- ." ]
    [ "${capture[1]}" = "git-stub fetch" ]
    [ "${capture[2]}" = "git-stub checkout foo --" ]
    [ "${capture[3]}" = "git-stub add ." ]
    # [ "${capture[4]}" = "git-stub -c user.name=Test Suite -c user.email=test@github.com commit -m Commit Message --author=Test Suite <test@users.noreply.github.com>" ]
    [ "${capture[5]}" = "git-stub push --set-upstream origin HEAD:foo --tags" ]

}

@test "can-work-with-empty-branch-name" {

    INPUT_BRANCH=""

    touch "${test_repository}"/new-file-{1,2,3}.txt

    shellmock_expect git --type partial --output " M new-file-1.txt M new-file-2.txt M new-file-3.txt" --match "status"
    shellmock_expect git --type exact --match "fetch"
    shellmock_expect git --type exact --match "checkout --"
    shellmock_expect git --type partial --match "add ."
    shellmock_expect git --type partial --match '-c'
    shellmock_expect git --type partial --match 'push origin'

    run main

    echo "$output"

    # Success Exit Code
    [ "$status" = 0 ]

    [ "${lines[0]}" = "INPUT_REPOSITORY value: ${INPUT_REPOSITORY}" ]
    [ "${lines[1]}" = "::set-output name=changes_detected::true" ]
    [ "${lines[2]}" = "INPUT_BRANCH value: " ]
    [ "${lines[3]}" = "INPUT_FILE_PATTERN: ." ]
    [ "${lines[4]}" = "INPUT_COMMIT_OPTIONS: " ]
    [ "${lines[5]}" = "::debug::Apply commit options " ]
    [ "${lines[6]}" = "INPUT_TAGGING_MESSAGE: " ]
    [ "${lines[7]}" = "No tagging message supplied. No tag will be added." ]
    [ "${lines[8]}" = "INPUT_PUSH_OPTIONS: " ]
    [ "${lines[9]}" = "::debug::Apply push options " ]
    [ "${lines[10]}" = "::debug::git push origin" ]


    shellmock_verify
    [ "${capture[0]}" = "git-stub status -s -- ." ]
    [ "${capture[1]}" = "git-stub fetch" ]
    [ "${capture[2]}" = "git-stub checkout --" ]
    [ "${capture[3]}" = "git-stub add ." ]
    # [ "${capture[4]}" = "git-stub -c user.name=Test Suite -c user.email=test@github.com commit -m Commit Message --author=Test Suite <test@users.noreply.github.com>" ]
    [ "${capture[5]}" = "git-stub push origin" ]
}

@test "can-work-with-empty-branch-name-and-tags" {

    INPUT_BRANCH=""
    INPUT_TAGGING_MESSAGE="v2.0.0"

    touch "${test_repository}"/new-file-{1,2,3}.txt

    shellmock_expect git --type partial --output " M new-file-1.txt M new-file-2.txt M new-file-3.txt" --match "status"
    shellmock_expect git --type exact --match "fetch"
    shellmock_expect git --type exact --match "checkout --"
    shellmock_expect git --type partial --match "add ."
    shellmock_expect git --type partial --match '-c'
    shellmock_expect git --type partial --match 'push origin'

    run main

    echo "$output"

    # Success Exit Code
    [ "$status" = 0 ]

    [ "${lines[0]}" = "INPUT_REPOSITORY value: ${INPUT_REPOSITORY}" ]
    [ "${lines[1]}" = "::set-output name=changes_detected::true" ]
    [ "${lines[2]}" = "INPUT_BRANCH value: " ]
    [ "${lines[3]}" = "INPUT_FILE_PATTERN: ." ]
    [ "${lines[4]}" = "INPUT_COMMIT_OPTIONS: " ]
    [ "${lines[5]}" = "::debug::Apply commit options " ]
    [ "${lines[6]}" = "INPUT_TAGGING_MESSAGE: v2.0.0" ]
    [ "${lines[7]}" = "::debug::Create tag v2.0.0" ]
    [ "${lines[8]}" = "INPUT_PUSH_OPTIONS: " ]
    [ "${lines[9]}" = "::debug::Apply push options " ]
    [ "${lines[10]}" = "::debug::git push origin --tags" ]


    shellmock_verify
    [ "${capture[0]}" = "git-stub status -s -- ." ]
    [ "${capture[1]}" = "git-stub fetch" ]
    [ "${capture[2]}" = "git-stub checkout --" ]
    [ "${capture[3]}" = "git-stub add ." ]
    # [ "${capture[4]}" = "git-stub -c user.name=Test Suite -c user.email=test@github.com commit -m Commit Message --author=Test Suite <test@users.noreply.github.com>" ]
    [ "${capture[5]}" = "git-stub -c user.name=Test Suite -c user.email=test@github.com tag -a v2.0.0 -m v2.0.0" ]
    [ "${capture[6]}" = "git-stub push origin --tags" ]

}
