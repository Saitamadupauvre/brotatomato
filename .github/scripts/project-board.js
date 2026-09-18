const STATUS = {
  backlog: 'Backlog',
  ready: 'Ready',
  inProgress: 'In progress',
  inReview: 'In review',
  onDev: 'On dev',
  onMain: 'On main',
};

const RANK = [
  STATUS.backlog,
  STATUS.ready,
  STATUS.inProgress,
  STATUS.inReview,
  STATUS.onDev,
  STATUS.onMain,
];

const CLOSING_KEYWORDS =
  /\b(?:close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s*:?\s+#(\d+)/gi;

const MAX_ISSUE_PAGES = 5;

const QUERY_PROJECT = `
  query($owner: String!, $number: Int!) {
    repositoryOwner(login: $owner) {
      ... on ProjectV2Owner {
        projectV2(number: $number) {
          id
          fields(first: 50) {
            nodes {
              ... on ProjectV2SingleSelectField { id name options { id name } }
            }
          }
        }
      }
    }
  }`;

const MUTATION_ADD_ITEM = `
  mutation($projectId: ID!, $contentId: ID!) {
    addProjectV2ItemById(input: { projectId: $projectId, contentId: $contentId }) {
      item {
        id
        status: fieldValueByName(name: "Status") {
          ... on ProjectV2ItemFieldSingleSelectValue { name }
        }
        priority: fieldValueByName(name: "Priority") {
          ... on ProjectV2ItemFieldSingleSelectValue { name }
        }
      }
    }
  }`;

const MUTATION_SET_FIELD = `
  mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
    updateProjectV2ItemFieldValue(input: {
      projectId: $projectId
      itemId: $itemId
      fieldId: $fieldId
      value: { singleSelectOptionId: $optionId }
    }) {
      projectV2Item { id }
    }
  }`;

const QUERY_ITEMS = `
  query($projectId: ID!, $after: String) {
    node(id: $projectId) {
      ... on ProjectV2 {
        items(first: 100, after: $after) {
          pageInfo { hasNextPage endCursor }
          nodes {
            id
            status: fieldValueByName(name: "Status") {
              ... on ProjectV2ItemFieldSingleSelectValue { name }
            }
            content {
              ... on Issue { id number state repository { name owner { login } } }
            }
          }
        }
      }
    }
  }`;

const QUERY_LINKED_BRANCHES = `
  query($owner: String!, $repo: String!, $after: String) {
    repository(owner: $owner, name: $repo) {
      issues(first: 100, after: $after, states: OPEN, orderBy: { field: UPDATED_AT, direction: DESC }) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id number state repository { name owner { login } }
          linkedBranches(first: 20) { nodes { ref { name } } }
        }
      }
    }
  }`;

const QUERY_ISSUE = `
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $number) { id number state repository { name owner { login } } }
    }
  }`;

class Board {
  constructor({ github, core, cfg }) {
    this._github = github;
    this._core = core;
    this._cfg = cfg;
    this._projectId = null;
    this._status = null;
    this._priority = null;
  }

  async load() {
    const data = await this._github.graphql(QUERY_PROJECT, {
      owner: this._cfg.owner,
      number: this._cfg.number,
    });
    const project = data.repositoryOwner && data.repositoryOwner.projectV2;
    if (!project) {
      throw new Error(`project #${this._cfg.number} owned by ${this._cfg.owner} not found (check PROJECT_TOKEN scopes)`);
    }
    this._projectId = project.id;
    const byName = new Map(project.fields.nodes.filter((f) => f.name).map((f) => [f.name, f]));
    this._status = this._indexField(byName.get('Status'), 'Status');
    this._priority = byName.has('Priority') ? this._indexField(byName.get('Priority'), 'Priority') : null;
    for (const name of RANK) {
      if (!this._status.options.has(name)) {
        throw new Error(`Status field is missing option "${name}" — rerun github-project-init`);
      }
    }
  }

  _indexField(field, label) {
    if (!field || !field.options) throw new Error(`single-select field "${label}" not found on project`);
    return { id: field.id, options: new Map(field.options.map((o) => [o.name, o.id])) };
  }

  rank(statusName) {
    return RANK.indexOf(statusName);
  }

  async ensureItem(issue) {
    const data = await this._github.graphql(MUTATION_ADD_ITEM, {
      projectId: this._projectId,
      contentId: issue.id,
    });
    const item = data.addProjectV2ItemById.item;
    return {
      id: item.id,
      issue,
      status: item.status ? item.status.name : null,
      priority: item.priority ? item.priority.name : null,
    };
  }

  async setStatus(item, statusName) {
    if (item.status === statusName) return false;
    await this._setOption(item.id, this._status, statusName);
    this._core.info(`#${item.issue.number}: ${item.status || '(none)'} -> ${statusName}`);
    item.status = statusName;
    return true;
  }

  async setIfBelow(item, statusName) {
    if (this.rank(item.status) >= this.rank(statusName)) return false;
    return this.setStatus(item, statusName);
  }

  async ensurePriority(item) {
    const wanted = this._cfg.defaultPriority;
    if (!wanted || !this._priority || item.priority) return false;
    if (!this._priority.options.has(wanted)) {
      this._core.warning(`default priority "${wanted}" is not an option of the Priority field`);
      return false;
    }
    await this._setOption(item.id, this._priority, wanted);
    this._core.info(`#${item.issue.number}: priority -> ${wanted}`);
    item.priority = wanted;
    return true;
  }

  async _setOption(itemId, field, optionName) {
    await this._github.graphql(MUTATION_SET_FIELD, {
      projectId: this._projectId,
      itemId,
      fieldId: field.id,
      optionId: field.options.get(optionName),
    });
  }

  async itemsWithStatus(statusName) {
    const found = [];
    let after = null;
    do {
      const data = await this._github.graphql(QUERY_ITEMS, { projectId: this._projectId, after });
      const page = data.node.items;
      for (const node of page.nodes) {
        const status = node.status ? node.status.name : null;
        if (status === statusName && node.content && node.content.number !== undefined) {
          found.push({ id: node.id, issue: node.content, status, priority: null });
        }
      }
      after = page.pageInfo.hasNextPage ? page.pageInfo.endCursor : null;
    } while (after);
    return found;
  }
}

class Repo {
  constructor({ github, core, owner, name }) {
    this._github = github;
    this._core = core;
    this.owner = owner;
    this.name = name;
  }

  async issue(number) {
    try {
      const data = await this._github.graphql(QUERY_ISSUE, { owner: this.owner, repo: this.name, number });
      return data.repository.issue;
    } catch (err) {
      this._core.info(`#${number}: not an issue in ${this.owner}/${this.name}, skipped (${err.message})`);
      return null;
    }
  }

  async issuesLinkedToBranch(branch) {
    const found = [];
    let after = null;
    let pages = 0;
    do {
      const data = await this._github.graphql(QUERY_LINKED_BRANCHES, { owner: this.owner, repo: this.name, after });
      const page = data.repository.issues;
      for (const issue of page.nodes) {
        if (issue.linkedBranches.nodes.some((b) => b.ref && b.ref.name === branch)) found.push(issue);
      }
      after = page.pageInfo.hasNextPage ? page.pageInfo.endCursor : null;
      pages += 1;
    } while (after && pages < MAX_ISSUE_PAGES);
    return found;
  }

  async closeIssue(issue) {
    if (issue.state === 'CLOSED') return false;
    await this._github.rest.issues.update({
      owner: issue.repository.owner.login,
      repo: issue.repository.name,
      issue_number: issue.number,
      state: 'closed',
      state_reason: 'completed',
    });
    this._core.info(`#${issue.number}: closed`);
    issue.state = 'CLOSED';
    return true;
  }
}

function issueNumbersFromText(text) {
  const numbers = new Set();
  for (const match of (text || '').matchAll(CLOSING_KEYWORDS)) numbers.add(Number(match[1]));
  return numbers;
}

function issueNumbersFromCommits(commits) {
  const numbers = new Set();
  for (const commit of commits || []) {
    for (const n of issueNumbersFromText(commit.message)) numbers.add(n);
  }
  return [...numbers];
}

function payloadIssue(issue) {
  return {
    id: issue.node_id,
    number: issue.number,
    state: issue.state === 'closed' ? 'CLOSED' : 'OPEN',
  };
}

async function landIssues(board, repo, issues, statusName) {
  for (const issue of issues) {
    const item = await board.ensureItem(issue);
    await board.setIfBelow(item, statusName);
    await board.ensurePriority(item);
    await repo.closeIssue(issue);
  }
}

async function onIssues(board, payload) {
  const issue = payloadIssue(payload.issue);
  const assigned = (payload.issue.assignees || []).length > 0;
  switch (payload.action) {
    case 'opened':
    case 'reopened': {
      const item = await board.ensureItem(issue);
      await board.setStatus(item, assigned ? STATUS.ready : STATUS.backlog);
      await board.ensurePriority(item);
      break;
    }
    case 'assigned': {
      const item = await board.ensureItem(issue);
      await board.setIfBelow(item, STATUS.ready);
      await board.ensurePriority(item);
      break;
    }
    case 'unassigned': {
      if (assigned) break;
      const item = await board.ensureItem(issue);
      if (item.status === STATUS.ready) await board.setStatus(item, STATUS.backlog);
      break;
    }
    default:
      break;
  }
}

async function onBranch({ board, repo, cfg, core }, branch) {
  if (branch === cfg.devBranch || branch === cfg.mainBranch) return;
  const issues = await repo.issuesLinkedToBranch(branch);
  if (issues.length === 0) {
    core.info(`branch ${branch}: no linked issue`);
    return;
  }
  for (const issue of issues) {
    const item = await board.ensureItem(issue);
    await board.setIfBelow(item, STATUS.inProgress);
    await board.ensurePriority(item);
  }
}

async function onPush(env, payload) {
  const { board, repo, cfg } = env;
  const prefix = 'refs/heads/';
  if (!payload.ref.startsWith(prefix)) return;
  const branch = payload.ref.slice(prefix.length);
  if (branch !== cfg.devBranch && branch !== cfg.mainBranch) {
    await onBranch(env, branch);
    return;
  }
  const target = branch === cfg.devBranch ? STATUS.onDev : STATUS.onMain;
  const issues = [];
  for (const number of issueNumbersFromCommits(payload.commits)) {
    const issue = await repo.issue(number);
    if (issue) issues.push(issue);
  }
  await landIssues(board, repo, issues, target);
}

async function onPullRequest({ board, repo, cfg, core }, payload) {
  const pr = payload.pull_request;
  const numbers = issueNumbersFromText(`${pr.title}\n${pr.body || ''}`);
  const issues = [];
  for (const number of numbers) {
    const issue = await repo.issue(number);
    if (issue) issues.push(issue);
  }
  switch (payload.action) {
    case 'opened':
    case 'reopened':
    case 'edited':
    case 'ready_for_review': {
      const target = pr.draft ? STATUS.inProgress : STATUS.inReview;
      for (const issue of issues) {
        const item = await board.ensureItem(issue);
        await board.setIfBelow(item, target);
        await board.ensurePriority(item);
      }
      break;
    }
    case 'converted_to_draft': {
      for (const issue of issues) {
        const item = await board.ensureItem(issue);
        if (item.status === STATUS.inReview) await board.setStatus(item, STATUS.inProgress);
      }
      break;
    }
    case 'closed': {
      if (!pr.merged) {
        for (const issue of issues) {
          const item = await board.ensureItem(issue);
          if (item.status === STATUS.inReview) await board.setStatus(item, STATUS.inProgress);
        }
        break;
      }
      const base = pr.base.ref;
      if (base === cfg.devBranch) {
        await landIssues(board, repo, issues, STATUS.onDev);
        break;
      }
      if (base === cfg.mainBranch) {
        const headRepo = pr.head.repo ? pr.head.repo.full_name : null;
        const fromDev = pr.head.ref === cfg.devBranch && headRepo === payload.repository.full_name;
        if (fromDev) {
          const staged = await board.itemsWithStatus(STATUS.onDev);
          core.info(`${cfg.devBranch} -> ${cfg.mainBranch} merged: promoting ${staged.length} item(s)`);
          for (const item of staged) {
            await board.setStatus(item, STATUS.onMain);
            await repo.closeIssue(item.issue);
          }
        }
        await landIssues(board, repo, issues, STATUS.onMain);
      }
      break;
    }
    default:
      break;
  }
}

module.exports = async ({ github, context, core }) => {
  const cfg = {
    owner: process.env.PROJECT_OWNER,
    number: Number(process.env.PROJECT_NUMBER),
    devBranch: process.env.DEV_BRANCH || 'dev',
    mainBranch: process.env.MAIN_BRANCH || 'main',
    defaultPriority: process.env.DEFAULT_PRIORITY || '',
  };
  if (!cfg.owner || !Number.isInteger(cfg.number) || cfg.number <= 0) {
    core.setFailed('PROJECT_OWNER / PROJECT_NUMBER env not set');
    return;
  }

  const board = new Board({ github, core, cfg });
  await board.load();
  const repo = new Repo({ github, core, owner: context.repo.owner, name: context.repo.repo });
  const env = { board, repo, cfg, core };
  const { payload } = context;

  switch (context.eventName) {
    case 'issues':
      await onIssues(board, payload);
      break;
    case 'create':
      if (payload.ref_type === 'branch') await onBranch(env, payload.ref);
      break;
    case 'push':
      await onPush(env, payload);
      break;
    case 'pull_request':
    case 'pull_request_target':
      await onPullRequest(env, payload);
      break;
    default:
      core.info(`event ${context.eventName} ignored`);
  }
};

module.exports.STATUS = STATUS;
module.exports.issueNumbersFromCommits = issueNumbersFromCommits;
module.exports.issueNumbersFromText = issueNumbersFromText;
