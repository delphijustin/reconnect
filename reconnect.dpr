program reconnect;

{$APPTYPE CONSOLE}

{$R *.res}
{$Resource reconnectdata.res}

uses
  SysUtils,
  windows,
  shellapi,
  urlmon,
  math,
  classes,mmsystem;
const Labels:array[0..2]of string=('Status','ISP-Name','IP');
REG_APPKEY='Software\Justin\Reconnect';
REG_MEMORY='Memory';
REG_PROCESSID='ProcessID';
REG_PORTS='Ports';
var downloader,h:THandle;
tid,pid,rs,error:dword;
I:Integer;
script:Shellexecuteinfo;
portnum:array[0..15]of char;
lastISP:String;
concount:NativeInt=-1;
url,datafile,portfile,sockerror:array[0..max_path] of char;
isp,params:TStringlist;
appusr,memkey,portstat:hkey;
tcpports:tlist;
tray:NOTIFYICONDATA;
label done;
function ISPFormat:PChar;
begin
result:=strplcopy(stralloc(length(isp.text)+1),stringreplace(isp.delimitedtext,
',',' ',[rfreplaceall]),length(isp.text)+1);
end;

function openPortsThread(rnd:nativeint):HResult;stdcall;
var strTCP:String;
I:integer;
begin
  strtcp:='';
for I := 0 to tcpports.Count-1 do
StrTCP:=format('%s&port%d=%u',[strtcp,i,Word(tcpports[i])]);
result:=urldownloadtocachefile(nil,strfmt(url,
'%s://delphianserver.com/port.php?cb=%d&rnd=%x%s',[params.Values['/proto'],
tcpports.count,rnd,strTCP]),portfile,max_path,0,nil);
end;

function downloadThread(rnd:nativeint):hresult;stdcall;
begin
result:=urldownloadtocachefile(nil,strfmt(url,
'http://ip-api.com/line/?rnd=%x&fields=status,isp,query',[
rnd]),datafile,max_path,0,nil);
end;
label loop;
begin
  try
  strcopy(datafile,':');
  if paramstr(1)='/?' then
  begin
    writeln('Usage: ',extractfilename(Paramstr(0)),
' [/proto=https|http] [/porttime=<seconds>] [/tcp=PortNum] [/kill] [/info] [/wave=<wavefile>] [/delay=<seconds>] [/timeout=<seconds>] [/hide]');
    writeln('Parameters:');
    writeln('/kill        Kills the running process');
    writeln('/proto       Sets the web protocol used for open ports result, can be http or https');
    writeln('/porttime    Open port request timeout');
    writeln('/tcp         Checks for an open port, you can use /tcp more than once');
    writeln('/info        Just get the Internet Service Provider name and quit. Do this first so you know how to setup the batch file');
    writeln('/wave        Use a different wave file instead of the built-in one');
    writeln('/delay       Specifies the delay in seconds. This parameter should be left alone since ip-api.com will block requests if they make more than 45 request per minute. Default is 60 seconds.');
    writeln('/timeout     Specifies the download timeout. Default 45 seconds.');
    writeln('/hide        Hides the console window. NOTE: This commandline switch makes it where this window cannot be used again. Any logging must be done in the batch file.');
   exitprocess(0);
  end;
  zeromemory(@tray,sizeof(tray));
  tray.cbSize:=sizeof(tray);
  tray.Wnd:=getconsolewindow;
  tray.uFlags:=nif_icon or nif_tip;
  tray.hIcon:=loadicon(hinstance,'MAINICON');
  strcopy(tray.szTip,'Loading...');
  randomize;//make the rnd url parameter different for each request
  isp:=tstringlist.create;//Create the ISP Stringlist
  isp.Quotechar:=':';
  params:=tstringlist.Create;
  params.Delimiter:=#32;
  params.DelimitedText:=getcommandline;
  pid:=0;
  if comparetext('https',params.values['/proto'])*comparetext('http',
  params.Values['/proto'])<>0then params.values['/proto']:='https';
  if params.IndexOf('/kill')>0then
  begin
    regopenkeyex(hkey_current_user,reg_appkey,0,key_all_access,appusr);
    regopenkeyex(appusr,reg_memory,0,key_all_access,memkey);
    rs:=4;
    regqueryvalueex(appusr,REG_PROCESSID,nil,nil,@pid,@rs);
    h:=openprocess(process_terminate,false,pid);
    if h<>0then begin
      if terminateprocess(h,2) then writeln(syserrormessage(0))else
      writeln(syserrormessage(getlasterror));
      closehandle(H);
    end else writeln(syserrormessage(getlasterror));
    regclosekey(memkey);regclosekey(appusR);
    exitprocess(getlasterroR);
  end;
  if params.indexof('/info')>0 then
  begin
  error:=dword(downloadthread(random(maxint)));
  case error of
  DWord(E_FAIL):isp.text:='DOWNLOAD ERROR FAILED';
  dword(E_OUTOFMEMORY):isp.text:='DOWNLOAD ERROR OUT_OF_MEMORY';
  s_ok:isp.loadfromfile(datafile);
  else isp.text:='DOWNLOAD ERROR 0x'+inttohex(error);
  end;
deletefile(datafile);
writeln(ispformat);
exitprocess(ord((pos('fail',isp.text)=1)or(pos('DOWNLOAD ERROR ',isp.text)=1)));
  end;
  tcpports:=tlist.create;
  for i:=1to params.count-1do
  if comparetext('/tcp',params.Names[i])=0then tcpports.Add(Pointer(StrToUIntDef(
  params.ValueFromIndex[i],0)));
  pid:=getcurrentprocessid;
  regcreatekeyex(hkey_current_user,reg_appkey,0,nil,reg_option_non_volatile,
  key_all_access,nil,appusr,nil);
  regcreatekeyex(appusr,reg_memory,0,nil,reg_option_volatile,key_all_access,nil,
  memkey,nil);
  regsetvalueex(memkey,REG_PROCESSID,0,reg_dword,@pid,4);
  regcreatekeyex(memkey,reg_ports,0,nil,reg_option_volatile,key_all_access,nil,
  portstat,nil);
    shell_notifyicon(nim_add,@tray);
  zeromemory(@script,sizeof(Script));//setup the script variable
  script.cbSize:=sizeof(script);
  script.lpFile:=strpcopy(stralloc(max_path),changefileext(paramstr(0),'.bat'));
//The script will be the executable name but instead of ending .exe it ends with .bat
  script.lpParameters:=stralloc(255);//initialize script parameters
  script.nShow:=sw_hide;
  script.fMask:=SEE_MASK_NOCLOSEPROCESS or SEE_MASK_FLAG_NO_UI or
  SEE_MASK_NO_CONSOLE;
  if params.IndexOf('/hide')>0then showwindow(getconsolewindow,sw_hide);
  loop:
  strcopy(datafile,':');
  downloader:=createthread(nil,0,@DownloadThread,pointer((makelong(random(
  maxword+1),random(maxword+1)))),0,tid);
  waitforsingleobject(downloader,strtointdef(params.Values['/timeout'],45)*1000);//download timeout at 45 seconds.
  getexitcodethread(downloader,error);
  case error of
  still_active:begin
  isp.Text:='DOWNLOAD ERROR TIMEOUT';Terminatethread(downloader,0);
  end;
  dword(E_FAIL):ISP.Text:='DOWNLOAD ERROR FAILED';
  dword(E_OUTOFMEMORY):ISP.Text:='DOWNLOAD ERROR OUT_OF_MEMORY';
  else isp.Text:='DOWNLOAD ERROR 0x'+inttohex(error);
  end;
  closehandle(downloader);
  if fileexists(datafile) then
  isp.LoadFromFile(datafile);
  if lastisp<>isp.Text then
  begin
  write('[',datetimetostr(now),']');
  for I := 0 to min(isp.count-1,2) do
    write(' - ',labels[i],':',isp[i]);
    writeln;
  inc(concount);
  strlfmt( tray.szTip,length(tray.szTip),
  '%d ISP Changes, last change at %s - %s',[concount,datetimetostr(now),isp.Text]
  );Shell_NotifyIcon(nim_modify,@tray);
  if params.IndexOfName('/wave')=-1 then
  playsound(makeintresource(1),hinstance,snd_resource or snd_sync)else
  playsound(PChar(params.Values['/wave']),0,snd_filename or snd_sync);
  lastisp:=isp.Text;
  end;
  deletefile(datafile);
  script.hProcess:=0;
  strlcopy(script.lpParameters,ispformat,255);
  shellexecuteex(@Script);
if script.hProcess<>0then begin
 waitforsingleobject(script.hProcess,infinite);
 closehandle(script.hProcess);
end;
if tcpports.Count>0then begin
  downloader:=createthread(nil,0,@openportsThread,pointer(makelong(random(
  maxword+1),random(maxword+1))),0,tid);
  waitforsingleobject(downloader,strtointdef(params.Values['/porttime'],4*60)*
  1000);//port timeout at 4 minutes.
  getexitcodethread(downloader,error);
  case error of
  still_active:begin
  isp.Text:='DOWNLOAD ERROR TIMEOUT';Terminatethread(downloader,0);
  end;
  dword(E_FAIL):ISP.Text:='DOWNLOAD ERROR FAILED';
  dword(E_OUTOFMEMORY):ISP.Text:='DOWNLOAD ERROR OUT_OF_MEMORY';
  else isp.Text:='DOWNLOAD ERROR 0x'+inttohex(error);
  end;
  closehandle(downloader);
  if fileexists(portfile) then
  begin
  strcopy(script.lpParameters,'/TCP ');
  for I:=0to tcpports.Count-1 do
  case getprivateprofileint(strlfmt(portnum,15,'PORT%u',[word(tcpports[i])]),
  'status',2,portfile) of
  0:begin
  getprivateprofilestring(portnum,'message','Unknown error',sockerror,max_path+1,
  portfile); erroR:=0;regsetvalueex(portstat,portnum,0,reg_dword,@error,4);
    writeln('[',datetimetostr(now),'] Port ',word(tcpports[i]),' not forwarded(',
    getprivateprofileint(portnum,'code',0,portfile),'):',sockerror);
    strfmt(strend(script.lpParameters),'%u ',[Word(tcpports[i])]);
  end;
  1:begin writeln('[',datetimetostr(now),'] Port ',Word(tcpports[i]),' is forwarded');
  error:=1;regsetvalueex(portstat,portnum,0,reg_dword,@error,4);
  end;
  else BEGIN writeln('[',datetimetostr(now),'] Bad Data from server');
  error:=2;  error:=1;regsetvalueex(portstat,portnum,0,reg_dword,@error,4);
      strfmt(strend(script.lpParameters),'%u ',[Word(tcpports[i])]);
  END;
  end;
end;
if stricomp(script.lpParameters,'/TCP ')=0then strcat(script.lpParameters,'OK');
script.hProcess:=0;
if shellexecuteex(@SCRIPT) then
waitforsingleobjecT(script.hProcess,infinite);
if script.hProcess<>0then closehandle(script.hProcess);
deletefile(portfile);
end;
  sleep(strtointdef(params.Values['/delay'],60)*1000);
  //for free access to ip-api.com it is recommended to keep it at 1 minute
  goto loop;
    { TODO -oUser -cConsole Main : Insert code here }
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  shell_notifyicon(nim_delete,@tray);
  writeln('Press enter to quit...');readln;
end.
