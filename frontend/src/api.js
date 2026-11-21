const use_cgi = 1;
const CGI_BASE_URL = 'http://192.168.1.170/cgi-bin/api/posts.cgi';
//const CGI_BASE_URL = ${window.location.origin}/cgi-bin/api/posts.cgi;
const MOJO_BASE_URL = 'http://localhost:3000/api/posts';

export const requestApi = async ({ method = 'GET', id = null, query = {}, body = null } = {}) => {
  const params = new URLSearchParams();
  for (const [k, v] of Object.entries(query)) {
    if (v !== undefined && v !== null && String(v) !== '') {
      params.set(k, String(v));
    }
  }

  let url = '';
  if (use_cgi === 1) {
    if (id !== null) params.set('id', String(id));
    const qs = params.toString();
    url = qs ? `${CGI_BASE_URL}?${qs}` : CGI_BASE_URL;
  } else {
    const qs = params.toString();
    const base = id !== null ? `${MOJO_BASE_URL}/${id}` : MOJO_BASE_URL;
    url = qs ? `${base}?${qs}` : base;
  }

  const options = { method };
  if (body) {
    options.headers = { 'Content-Type': 'application/json' };
    options.body = JSON.stringify(body);
  }

  const res = await fetch(url, options);
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || '通信エラーが発生しました');
  return data;
};

