import {DatabaseSync} from 'node:sqlite';
import {writeFileSync} from 'node:fs';

// Explicitly approved, read-only diagnostics. Keep the key only in memory.
const db = new DatabaseSync('C:/ProgramData/Jellyfin/Server/data/jellyfin.db', {readOnly:true});
const key = db.prepare('SELECT AccessToken FROM ApiKeys WHERE Name=?').get('Wizard')?.AccessToken;
db.close();
if (!key) throw Error('Approved key unavailable.');
const headers = {Authorization: `MediaBrowser Token="${key}"`};
async function get(route, query = {}) {
  const start = Date.now();
  const response = await fetch(`http://127.0.0.1:8097${route}?${new URLSearchParams(query)}`, {
    headers, redirect:'error', signal:AbortSignal.timeout(60000),
  });
  const body = await response.json().catch(() => null);
  return {status:response.status, ms:Date.now()-start, contentType:response.headers.get('content-type'), body};
}
const users = await get('/Users');
const user = users.body.find(u => u.Name.toLowerCase() === 'daorigin');
if (!user) throw Error('Test user unavailable.');
const views = await get(`/Users/${user.Id}/Views`);
const modernViews = await get('/UserViews', {UserId:user.Id});
console.log(JSON.stringify({modernViewsStatus:modernViews.status,
  viewsMatch: JSON.stringify(views.body.Items.map(i => i.Id)) === JSON.stringify(modernViews.body?.Items?.map(i => i.Id))}));
const fixture = [];
for (const view of views.body.Items.filter(v => /\bvod\b/i.test(v.Name))) {
  const result = await get(`/Users/${user.Id}/Items`, {
    ParentId:view.Id, SearchTerm:'Reacher', Limit:'48', Recursive:'true',
    Fields:'Type,UserData,ProductionYear,SeriesName,ParentIndexNumber,IndexNumber,AlbumArtist,Album,ImageTags,BackdropImageTags,ParentBackdropItemId,ParentBackdropImageTags,SeriesId,SeriesPrimaryImageTag,ProviderIds',
  });
  console.log(JSON.stringify({library:view.Name, type:view.CollectionType, status:result.status, ms:result.ms, contentType:result.contentType,
    count:result.body?.Items?.length, errors:result.body?.errors, title:result.body?.title,
    contentTypes: [...new Set((result.body?.Items ?? []).map(i => i.Type))],
    invalid: (result.body?.Items ?? []).filter(i =>
      typeof i.Name !== 'string' || (i.Type != null && typeof i.Type !== 'string') ||
      (i.ProviderIds != null && (typeof i.ProviderIds !== 'object' || Array.isArray(i.ProviderIds))))
      .map(i => ({name:i.Name, type:i.Type, providerIdsType:typeof i.ProviderIds}))}));
  fixture.push(...(result.body?.Items ?? []).map(i => Object.fromEntries(
    ['Id','ServerId','Name','Type','ProviderIds','ProductionYear'].filter(k => k in i).map(k => [k,i[k]]))));
}
writeFileSync(new URL('../verification/search-fixture.json', import.meta.url), JSON.stringify(fixture));
