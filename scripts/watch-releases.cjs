module.exports = async function ({ github, context, core }) {
    const upstream = { owner: 'lemonade-sdk', repo: 'lemonade' };
    const { data: repository } = await github.rest.repos.get(context.repo);
    const releases = await github.paginate(github.rest.repos.listReleases, { ...upstream, per_page: 100 });
    const stable = releases.filter(release => !release.draft && !release.prerelease && /^v\d+\.\d+\.\d+$/.test(release.tag_name));
    const { data: latest } = await github.rest.repos.getLatestRelease(upstream);
    const candidates = stable.filter(release => release.tag_name === latest.tag_name || release.published_at >= repository.created_at);
    const runs = await github.paginate(github.rest.actions.listWorkflowRuns, {
        ...context.repo, workflow_id: 'compatibility.yml', per_page: 100
    });
    for (const release of candidates.reverse()) {
        const tested = runs.some(run => run.display_title === `Lemonade ${release.tag_name}`
            && run.head_branch === repository.default_branch
            && (run.status !== 'completed' || run.conclusion === 'success'));
        if (tested) continue;
        await github.rest.actions.createWorkflowDispatch({
            ...context.repo, workflow_id: 'compatibility.yml', ref: repository.default_branch,
            inputs: { release: release.tag_name }
        });
        core.info(`Queued compatibility tests for ${release.tag_name}`);
    }
};
