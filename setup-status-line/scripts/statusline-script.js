#!/usr/bin/env node
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Read JSON input from stdin
let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);
    const output = generateStatusLine(data);
    process.stdout.write(output);
  } catch (e) {
    process.stdout.write('Error: ' + e.message);
  }
});

function formatTokens(n) {
  if (n >= 1000) {
    return (n / 1000).toFixed(1) + 'k';
  }
  return String(n);
}

function generateStatusLine(data) {
  // デバッグ用ダンプ
  const home = process.env.HOME;
  fs.writeFileSync(path.join(home, '.claude', 'statusline-input.json'), JSON.stringify(data, null, 2));

  // 基本情報抽出
  const model = (data.model?.display_name || 'Unknown').replace(/^Claude /, '');
  const dirFull = data.workspace?.current_dir || data.cwd || 'Unknown';
  const dir = dirFull.replace(home, '~');

  // 時間（APIから）
  const durationMs = data.cost?.total_duration_ms || 0;
  const minutes = Math.floor(durationMs / 60000);
  const seconds = Math.floor((durationMs % 60000) / 1000);
  const duration = `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;

  // トークン数（トランスクリプトから）
  let tokens = '--';
  const transcript = data.transcript_path;
  if (transcript && fs.existsSync(transcript)) {
    const content = fs.readFileSync(transcript, 'utf8');
    const inputMatches = content.match(/"input_tokens":(\d+)/g) || [];
    const outputMatches = content.match(/"output_tokens":(\d+)/g) || [];

    const inputTokens = inputMatches.reduce((sum, m) => sum + parseInt(m.match(/\d+/)[0], 10), 0);
    const outputTokens = outputMatches.reduce((sum, m) => sum + parseInt(m.match(/\d+/)[0], 10), 0);
    const totalTokens = inputTokens + outputTokens;
    tokens = `↑${formatTokens(inputTokens)} ↓${formatTokens(outputTokens)} (${formatTokens(totalTokens)})`;
  }

  // Git
  let gitInfo = '';
  try {
    execSync('git rev-parse --git-dir', { stdio: 'pipe' });
    let branch;
    try {
      branch = execSync('git rev-parse --abbrev-ref HEAD', { encoding: 'utf8', stdio: 'pipe' }).trim();
    } catch {
      branch = 'detached';
    }

    // Check for dirty (including untracked)
    const status = execSync('git --no-optional-locks status --porcelain -unormal --ignore-submodules=dirty', { encoding: 'utf8', stdio: 'pipe' });
    if (status.trim()) {
      branch += '*';
    }
    gitInfo = branch;
  } catch {
    // Not a git repo
  }

  // Context（ccusage）
  let context = '';
  try {
    const ccusageOutput = execSync(`echo '${JSON.stringify(data).replace(/'/g, "\\'")}' | npx ccusage statusline`, {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe']
    });
    const match = ccusageOutput.match(/🧠[^|]*/);
    if (match) {
      context = match[0].replace(/🧠\s*/, 'Context: ').trim();
    }
  } catch {
    // ccusage not available
  }

  // 出力
  const parts = [dir, gitInfo, model, duration, tokens, context].filter(Boolean);
  return parts.join(' | ');
}
