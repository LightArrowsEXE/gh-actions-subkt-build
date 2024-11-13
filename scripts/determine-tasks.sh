#!/bin/bash

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

log_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo "[DEBUG] $1"
    fi
}

get_changed_files() {
    local base_commit
    if [ "$GITHUB_EVENT_NAME" = "pull_request" ]; then
        base_commit="$GITHUB_BASE_SHA"
    else
        base_commit="$GITHUB_BEFORE_SHA"
    fi
    git diff --name-only "$base_commit" HEAD
}

get_episode_numbers() {
    local files="$1"
    echo "$files" | grep -oE '/[0-9]{2}/' | sort -u | tr -d '/' | tr -d '\n'
}

get_task_dependency_tree() {
    local episode=$1
    local task=$2
    local qualifier=${3:-default}

    local full_task="${task}.${episode}.${qualifier}"
    log_debug "Getting dependency tree for task: $full_task"

    ./gradlew dependencies --task "$full_task" --dry-run 2>/dev/null |
        grep -E '^\s*:' |
        awk '{print $1}' |
        sed 's/://'
}

get_leaf_tasks() {
    local dependency_tree="$1"
    local all_tasks=()
    local dependency_map=()

    while IFS= read -r task; do
        all_tasks+=("$task")

        local deps=$(echo "$dependency_tree" | grep -A1 "^$task$" | tail -n1)

        if [ -n "$deps" ]; then
            dependency_map+=("$task:$deps")
        fi
    done <<< "$dependency_tree"

    local leaf_tasks=()

    for task in "${all_tasks[@]}"; do
        if [[ $task =~ ^mux\. ]]; then
            continue
        fi

        local is_dependency=false
        local has_dependencies=false

        for dep_entry in "${dependency_map[@]}"; do
            if [[ $dep_entry == *":$task"* ]]; then
                is_dependency=true
            fi
            if [[ $dep_entry == "$task:"* ]]; then
                has_dependencies=true
                break
            fi
        done

        if [ "$is_dependency" = true ] && [ "$has_dependencies" = false ]; then
            leaf_tasks+=("$task")
        fi
    done

    echo "${leaf_tasks[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '
}

process_episode_tasks() {
    local episode=$1
    local mux_task=$2

    log_debug "Processing tasks for episode $episode"

    local dep_tree=$(get_task_dependency_tree "$episode" "$mux_task")
    local leaf_tasks=$(get_leaf_tasks "$dep_tree")

    echo "$leaf_tasks"
}

process_incremental() {
    local mux_task=$1
    local changed_files=$(get_changed_files)
    local episodes=$(get_episode_numbers "$changed_files")

    if [ -z "$episodes" ]; then
        log_info "No episode-specific changes detected"
        return 0
    fi

    local all_tasks=""

    for ep in $episodes; do
        local deps=$(process_episode_tasks "$ep" "$mux_task")
        all_tasks="$all_tasks $deps"
    done

    echo "tasks=${all_tasks}" >> $GITHUB_OUTPUT
}

process_direct_tasks() {
    local task_types="$1"
    local incremental="$2"
    log_info "Processing direct tasks: $task_types"

    local TASKS=""

    if [ "$incremental" = "true" ]; then
        EPISODES=$(get_changed_episodes)
    else
        EPISODES=$(./gradlew tasks --all | grep -oE '\.[0-9]+\.default' | sort -u | grep -oE '[0-9]+')
    fi

    for task_type in $(echo "$task_types" | tr ',' ' '); do
        for episode in $EPISODES; do
            episode=$(printf "%02d" "$episode")
            task="${task_type}.${episode}.default"

            if ./gradlew tasks --all | grep -q "^${task}"; then
                TASKS="$TASKS $task"
            fi
        done
    done

    echo "$TASKS"
}

if [ -n "$DIRECT_TASKS" ]; then
    log_info "Direct tasks specified"
    TASKS=$(process_direct_tasks "$DIRECT_TASKS" "$INCREMENTAL")
elif [ -n "$MUX_TASK" ]; then
    if [ "$INCREMENTAL" = "true" ]; then
        log_info "Running incremental build"

        TASKS=$(process_incremental "$MUX_TASK")
    else
        log_info "Running full build"

        TASKS=$(process_full_build "$MUX_TASK")
    fi
else
    log_info "No tasks specified"

    TASKS=""
fi

if [ -n "$TASKS" ]; then
    log_info "Selected tasks for execution: ${TASKS}"
    echo "tasks=${TASKS}" >> $GITHUB_OUTPUT
else
    log_info "No tasks to run"
    echo "tasks=" >> $GITHUB_OUTPUT
fi
