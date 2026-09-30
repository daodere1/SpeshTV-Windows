import {DatabaseSync} from 'node:sqlite';

// User-approved read-only checks. The existing local key never leaves memory
// except in authentication headers sent to this loopback Jellyfin server.
const db = new DatabaseSync('C:/ProgramData/Jellyfin/Server/data/jellyfin.db', {readOnly:true});
const key = db.prepare('SELECT AccessToken FROM ApiKeys WHERE Name=?').get('Wizard')?.AccessToken;
db.close();
if (!key) throw Error('Approved key unavailable.');
const headers = {Authorization: `MediaBrowser Token="${key}"`};
async function get(label, route, query = {}) {
  const started = Date.now();
  try {
    const response = await fetch(`http://127.0.0.1:8097${route}?${new URLSearchParams(query)}`, {
      headers, redirect:'error', signal:AbortSignal.timeout(65000),
    });
    const body = await response.json().catch(() => null);
    console.log(JSON.stringify({label,status:response.status,ms:Date.now()-started,
      count:body?.Items?.length,total:body?.TotalRecordCount}));
    return body;
  } catch (error) {
    console.log(JSON.stringify({label,error:error.name,ms:Date.now()-started}));
    return null;
  }
}
const users = await get('users', '/Users');
const user = users?.find(u => u.Name.toLowerCase() === 'daorigin');
if (!user) throw Error('Test user unavailable.');
const fields = 'DateCreated,Type,UserData,Overview,Genres,CommunityRating,CriticRating,OfficialRating,RunTimeTicks,ProductionYear,SeriesName,ParentIndexNumber,IndexNumber,Status,ImageTags,BackdropImageTags,ParentBackdropItemId,ParentBackdropImageTags,ParentThumbItemId,ParentThumbImageTag,SeriesId,SeriesPrimaryImageTag,ParentLogoItemId,ParentLogoImageTag,PrimaryImageTag,PrimaryImageAspectRatio';
const query = {UserId:user.Id,StartIndex:'0',Limit:'15',Fields:fields,EnableImageTypes:'Primary,Backdrop,Thumb,Banner',ImageTypeLimit:'1'};
if (process.argv.includes('--variants')) {
  const lean = {UserId:user.Id,StartIndex:'0',Limit:'15',EnableUserData:'true',ImageTypeLimit:'1',
    Fields:'ProviderIds,ProductionYear,PrimaryImageAspectRatio',EnableTotalRecordCount:'false'};
  await get('video-filter-resume', `/Users/${user.Id}/Items/Resume`, {...lean,MediaTypes:'Video',IncludeItemTypes:'Movie,Episode'});
  await get('regular-types-resume', `/Users/${user.Id}/Items/Resume`, {...lean,MediaTypes:'Video',IncludeItemTypes:'Movie,Episode,MusicVideo,Video'});
  process.exit(0);
}
if (process.argv.includes('--optimized')) {
  const lean = {UserId:user.Id,StartIndex:'0',Limit:'15',EnableUserData:'true',ImageTypeLimit:'1',
    Fields:'ProviderIds,ProductionYear,PrimaryImageAspectRatio',EnableTotalRecordCount:'false'};
  await get('optimized-resume', `/Users/${user.Id}/Items/Resume`, {...lean,MediaTypes:'Video',IncludeItemTypes:'Movie,Episode'});
  await get('optimized-next-up', '/Shows/NextUp', {...lean,EnableResumable:'false',EnableRewatching:'false'});
  process.exit(0);
}
if (process.argv.includes('--current')) {
  await get('current-moonfin-resume', '/UserItems/Resume', {...query,IncludeItemTypes:'Movie,Episode'});
  await get('current-moonfin-next-up', '/Shows/NextUp', {...query,EnableResumable:'false'});
  process.exit(0);
}
if (process.argv.includes('--regular')) {
  const regular = {UserId:user.Id,StartIndex:'0',Limit:'30',EnableUserData:'true',ImageTypeLimit:'1',
    Fields:'ProviderIds,ProductionYear,PrimaryImageAspectRatio',EnableTotalRecordCount:'false'};
  await get('regular-speshtv-resume', `/Users/${user.Id}/Items/Resume`, {...regular,
    MediaTypes:'Video',IncludeItemTypes:'Movie,Episode,MusicVideo,Video'});
  await get('regular-speshtv-next-up', '/Shows/NextUp', {...regular,EnableResumable:'false',EnableRewatching:'false'});
  process.exit(0);
}
if (process.argv.includes('--fallback')) {
  await get('resumable-items', `/Users/${user.Id}/Items`, {...query,
    Filters:'IsResumable', IncludeItemTypes:'Movie,Episode', Recursive:'true',
    SortBy:'DatePlayed', SortOrder:'Descending', EnableTotalRecordCount:'false'});
  process.exit(0);
}
if (process.argv.includes('--lean')) {
  const lean = {...query,Fields:'Type,UserData,RunTimeTicks,ProductionYear,SeriesName,ParentIndexNumber,IndexNumber,SeriesId,ImageTags,SeriesPrimaryImageTag,ParentThumbItemId,ParentThumbImageTag',EnableTotalRecordCount:'false'};
  await get('lean-resume', '/UserItems/Resume', {...lean,IncludeItemTypes:'Movie,Episode'});
  await get('lean-next-up', '/Shows/NextUp', {...lean,EnableResumable:'false'});
  process.exit(0);
}
const resume = await get('resume', '/UserItems/Resume', {...query,IncludeItemTypes:'Movie,Episode'});
const next = await get('next-up', '/Shows/NextUp', {...query,EnableResumable:'false'});
await get('views', `/Users/${user.Id}/Views`);
for (const [label,body] of [['resume',resume],['next-up',next]]) {
  console.log(JSON.stringify({label,invalid:(body?.Items ?? []).filter(i =>
    typeof i.Name !== 'string' || typeof i.Type !== 'string' ||
    (i.UserData?.PlaybackPositionTicks != null && typeof i.UserData.PlaybackPositionTicks !== 'number')
  ).length}));
  const entry = body?.Items?.[0];
  if (!entry) continue;
  const id = entry.Type === 'Episode' ? entry.SeriesId : entry.Id;
  await get(`${label}-identity`, `/Users/${user.Id}/Items/${id}`, {Fields:'ProviderIds,ProductionYear,Type'});
  await get(`${label}-ancestors`, `/Items/${id}/Ancestors`, {UserId:user.Id});
}
await get('next-up-last-played', `/Users/${user.Id}/Items`, {
  IncludeItemTypes:'Episode',Filters:'IsPlayed',Recursive:'true',SortBy:'DatePlayed',SortOrder:'Descending',Limit:'100',Fields:'UserData,SeriesId',
});
