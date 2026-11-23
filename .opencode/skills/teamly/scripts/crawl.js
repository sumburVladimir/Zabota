/* Teamly -> markdown crawl (v2). Runs inside the logged-in teamly tab.
   Вызов: window.__teamlyStart(); остановка: window.__teamlyStop = true.
   Файл без шаблонных строк, чтобы целиком передаваться в browser.evaluate. */
window.__teamlyStart = async () => {
  var API = 'https://app2.teamly.ru/api/v1';
  var H = { 'Accept': 'application/json', 'Content-Type': 'application/json', 'x-account-slug': 'zabota' };
  var SINK = 'http://127.0.0.1:8765/save';
  var FENCE = String.fromCharCode(96, 96, 96);
  var TICK = String.fromCharCode(96);

  var post = async function (url, body, method) {
    var opts = { method: method || 'POST', credentials: 'include', headers: H };
    if (body) opts.body = JSON.stringify(body);
    var res = await fetch(url, opts);
    if (!res.ok) throw new Error(url + ' -> ' + res.status);
    return res.json();
  };
  var get = function (url) { return post(url, null, 'GET'); };

  var esc = function (s) { return String(s).replace(/\s+/g, ' ').trim(); };
  var slug = function (s) {
    return String(s).replace(/[<>:"\/\\|?*\x00-\x1f]/g, '_').replace(/\s+/g, ' ').trim().slice(0, 120) || 'без названия';
  };

  function inline(nodes) {
    return (nodes || []).map(function (n) {
      if (n.type === 'text') {
        var t = n.text || '';
        (n.marks || []).forEach(function (m) {
          if (m.type === 'bold') t = '**' + t + '**';
          else if (m.type === 'italic') t = '*' + t + '*';
          else if (m.type === 'code') t = TICK + t + TICK;
          else if (m.type === 'strike') t = '~~' + t + '~~';
          else if (m.type === 'link') t = '[' + t + '](' + ((m.attrs && (m.attrs.href || m.attrs.target)) || '') + ')';
        });
        return t;
      }
      if (n.type === 'hardBreak') return '  \n';
      if (n.type === 'image') return '![' + ((n.attrs && n.attrs.alt) || '') + '](' + ((n.attrs && n.attrs.src) || '') + ')';
      if (n.type === 'mention') return (n.attrs && (n.attrs.label || n.attrs.id)) || '';
      return inline(n.content);
    }).join('');
  }

  function block(node, depth) {
    depth = depth || 0;
    var kids = node.content || [];
    var k;
    switch (node.type) {
      case 'doc': return kids.map(function (x) { return block(x, depth); }).join('\n\n').trim() + '\n';
      case 'heading':
        k = Math.min(6, Math.max(1, (node.attrs && node.attrs.level) || 2));
        return '#'.repeat(k) + ' ' + esc(inline(kids));
      case 'paragraph': return inline(kids);
      case 'blockquote':
        return kids.map(function (x) { return block(x, depth); }).join('\n\n').split('\n').map(function (l) { return '> ' + l; }).join('\n');
      case 'codeBlock':
        return FENCE + ((node.attrs && node.attrs.language) || '') + '\n' + kids.map(function (x) { return x.text || ''; }).join('') + '\n' + FENCE;
      case 'horizontalRule': return '---';
      case 'bulletList':
        return kids.map(function (li) {
          return (li.content || []).map(function (c) { return block(c, depth + 1); }).join('\n')
            .split('\n').map(function (l, i) { return (i === 0 ? '- ' : '  ') + l; }).join('\n');
        }).join('\n');
      case 'orderedList':
        return kids.map(function (li, idx) {
          return (li.content || []).map(function (c) { return block(c, depth + 1); }).join('\n')
            .split('\n').map(function (l, j) { return (j === 0 ? String(idx + 1) + '. ' : '   ') + l; }).join('\n');
        }).join('\n');
      case 'listItem': return kids.map(function (x) { return block(x, depth); }).join('\n');
      case 'table':
        var cellText = function (cell) {
          var parts = [];
          (cell.content || []).forEach(function (c) {
            if (c.type === 'paragraph' || c.type === 'heading') parts.push(inline(c.content));
            else if ((c.content || []).length) parts.push(inline(c.content));
            else parts.push(c.text || '');
          });
          return esc(parts.join(' ')).replace(/\|/g, '\\|');
        };
        var rows = kids.map(function (r) {
          return (r.content || []).map(cellText);
        });
        if (!rows.length) return '';
        var cols = rows.reduce(function (n, r) { return Math.max(n, r.length); }, 0);
        var norm = function (r) {
          var out = r.slice();
          while (out.length < cols) out.push('');
          return out;
        };
        rows = rows.map(norm);
        var head = rows[0];
        return ['| ' + head.join(' | ') + ' |', '| ' + head.map(function () { return '---'; }).join(' | ') + ' |']
          .concat(rows.slice(1).map(function (r) { return '| ' + r.join(' | ') + ' |'; })).join('\n');
      default:
        if (kids.length) return kids.map(function (x) { return block(x, depth); }).join('\n\n');
        return inline([node]);
    }
  }

  function toMarkdown(article, space) {
    var pm = {};
    try { pm = JSON.parse((article.editorContentObject && article.editorContentObject.content) || '{}'); } catch (e) { pm = {}; }
    var body = pm.content ? block(pm, 0) : '_Пустое содержимое_\n';
    var id = article.id;
    var title = (article.title && article.title.text) || '';
    return ['---','title: ' + JSON.stringify(title),'space: ' + JSON.stringify(space),'article_id: ' + id,
      'source: https://zabota.teamly.ru/at/' + id,'---','','# ' + title,'',body].join('\n');
  }

  var state = window.__teamlyCrawl = { phase: 'listing', done: 0, total: 0, errors: [], startedAt: Date.now(), finished: false };
  window.__teamlyStop = false;

  // 1. Все статьи, один проход, дедуп по id
  var seen = {};
  var tasks = [];
  for (var page = 1; page <= 40; page++) {
    var j = await post(API + '/wiki/ql/articles', { query: { __pagination: { page: page, per_page: 50 }, id: true, title: true, space: { id: true, title: true } } });
    var d = j.data || [];
    for (var i = 0; i < d.length; i++) {
      var a = d[i];
      if (seen[a.id]) continue;
      seen[a.id] = 1;
      tasks.push({ id: a.id, title: a.title, space: (a.space && a.space.title) || 'Без пространства' });
    }
    state.total = tasks.length;
    if (d.length < 50) break;
  }

  state.phase = 'fetching';
  var queue = tasks.slice();
  var worker = async function () {
    while (queue.length && !window.__teamlyStop) {
      var t = queue.shift();
      try {
        var article = await get(API + '/wiki/articles/' + t.id + '?viewMode=edit&latestVersionAt=1');
        var md = toMarkdown(article, t.space);
        var ttl = (article.title && article.title.text) || t.title;
        var path = slug(t.space) + '/' + slug(ttl) + ' [' + t.id.slice(0, 8) + '].md';
        var r = await fetch(SINK, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ path: path, content: md }) });
        if (!r.ok) throw new Error('sink ' + r.status);
      } catch (e) {
        state.errors.push({ id: t.id, title: t.title, error: String(e) });
      }
      state.done++;
    }
  };

  await Promise.all([worker(), worker(), worker(), worker()]);
  state.phase = window.__teamlyStop ? 'stopped' : 'done';
  state.finished = true;
  state.elapsedSec = Math.round((Date.now() - state.startedAt) / 1000);
  return { total: state.total, done: state.done, errors: state.errors.length };
};
