const assert = require('node:assert/strict');
const test = require('node:test');
const watch = require('../scripts/watch-releases.cjs');

test('discovers missed stable releases, retries failures, and skips successful or active runs', async () => {
    const queued = [];
    const releases = [
        {tag_name: 'v12.3.0', published_at: '2026-10-04'},
        {tag_name: 'v12.2.0', published_at: '2026-10-03'},
        {tag_name: 'v12.1.0', published_at: '2026-10-02'},
        {tag_name: 'v12.0.0', published_at: '2026-10-01'},
        {tag_name: 'v11.0.0', published_at: '2026-08-01'},
        {tag_name: 'v13.0.0', published_at: '2026-10-05', prerelease: true},
        {tag_name: 'v14.0.0', published_at: '2026-10-05', draft: true}
    ];
    const runs = [
        {display_title: 'Lemonade v12.0.0', head_branch: 'main', status: 'completed', conclusion: 'success'},
        {display_title: 'Lemonade v12.1.0', head_branch: 'main', status: 'completed', conclusion: 'failure'},
        {display_title: 'Lemonade v12.2.0', head_branch: 'main', status: 'in_progress'},
        {display_title: 'Lemonade v12.3.0', head_branch: 'experiment', status: 'completed', conclusion: 'success'}
    ];
    const github = {
        rest: {
            repos: {
                get: async () => ({data: {created_at: '2026-09-14', default_branch: 'main'}}),
                getLatestRelease: async () => ({data: releases[0]}),
                listReleases: 'releases'
            },
            actions: {
                listWorkflowRuns: 'runs',
                createWorkflowDispatch: async request => queued.push(request)
            }
        },
        paginate: async endpoint => endpoint === 'releases' ? releases : runs
    };
    await watch({github, context: {repo: {owner: 'lemonade-sdk', repo: 'omarchy-lemonade'}}, core: {info() {}}});
    assert.deepEqual(queued.map(request => request.inputs.release), ['v12.1.0', 'v12.3.0']);
    assert.ok(queued.every(request => request.ref === 'main' && request.workflow_id === 'compatibility.yml'));
});
