#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$OfficialDatPath,
    [Parameter(Mandatory=$true)][string]$OutputPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$ExpectedOfficialHash='D48791364C234736C54811EAE3708E0C6DB999B625F770350CAE9F4E02A3716D'
$ExpectedFinalHash='DD7B29271E068BE01F5FE4F55A136F0049F60822E0D789B9AAF9152E58A9D766'
$ReleaseVersion='26.10.35.01-260716a-202643C-AMD-Software-Adrenalin-Edition'
function Hash([string]$P){return(Get-FileHash -LiteralPath $P -Algorithm SHA256).Hash.ToUpperInvariant()}
if((Hash $OfficialDatPath)-ne $ExpectedOfficialHash){throw 'Official amdgcf.dat hash mismatch.'}
if(-not('AmdGcfMetroHash64V3RC2'-as[type])){
Add-Type -Language CSharp -TypeDefinition @'
using System;
public static class AmdGcfMetroHash64V3RC2 {
 const ulong K0=0xD6D018F5UL,K1=0xA2AA033BUL,K2=0x62992FC1UL,K3=0x30BC5B29UL;
 static ulong R(ulong v,int b){return(v>>b)|(v<<(64-b));}
 static ulong U64(byte[]d,int o){return((ulong)d[o])|((ulong)d[o+1]<<8)|((ulong)d[o+2]<<16)|((ulong)d[o+3]<<24)|((ulong)d[o+4]<<32)|((ulong)d[o+5]<<40)|((ulong)d[o+6]<<48)|((ulong)d[o+7]<<56);}
 static uint U32(byte[]d,int o){return((uint)d[o])|((uint)d[o+1]<<8)|((uint)d[o+2]<<16)|((uint)d[o+3]<<24);}
 static ushort U16(byte[]d,int o){return(ushort)(d[o]|(d[o+1]<<8));}
 public static ulong Compute(byte[]d,ulong seed,bool addLength){if(d==null)throw new ArgumentNullException("data");unchecked{int len=d.Length,o=0;ulong h=(seed+K2)*K0;if(addLength)h+=(ulong)len;if(len>=32){ulong v0=h,v1=h,v2=h,v3=h;int end=len-32;while(o<=end){v0+=U64(d,o)*K0;o+=8;v0=R(v0,29)+v2;v1+=U64(d,o)*K1;o+=8;v1=R(v1,29)+v3;v2+=U64(d,o)*K2;o+=8;v2=R(v2,29)+v0;v3+=U64(d,o)*K3;o+=8;v3=R(v3,29)+v1;}v2^=R(((v0+v3)*K0)+v1,37)*K1;v3^=R(((v1+v2)*K1)+v0,37)*K0;v0^=R(((v0+v2)*K0)+v3,37)*K1;v1^=R(((v1+v3)*K1)+v2,37)*K0;h+=v0^v1;}int rem=len-o;if(rem>=16){ulong v0=h+(U64(d,o)*K2);o+=8;v0=R(v0,29)*K3;ulong v1=h+(U64(d,o)*K2);o+=8;v1=R(v1,29)*K3;v0^=R(v0*K0,21)+v1;v1^=R(v1*K3,21)+v0;h+=v1;rem=len-o;}if(rem>=8){h+=U64(d,o)*K3;o+=8;h^=R(h,55)*K1;rem=len-o;}if(rem>=4){h+=(ulong)U32(d,o)*K3;o+=4;h^=R(h,26)*K1;rem=len-o;}if(rem>=2){h+=(ulong)U16(d,o)*K3;o+=2;h^=R(h,48)*K1;rem=len-o;}if(rem>=1){h+=(ulong)d[o]*K3;h^=R(h,37)*K1;}h^=R(h,28);h*=K0;h^=R(h,29);return h;}}
 public static byte[] Big(ulong v){return new byte[]{(byte)(v>>56),(byte)(v>>48),(byte)(v>>40),(byte)(v>>32),(byte)(v>>24),(byte)(v>>16),(byte)(v>>8),(byte)v};}
}
'@
}
function Get-Header([byte[]]$Dat,[string]$Release){
 [byte[]]$Records=[byte[]]::new($Dat.Length-12);[Array]::Copy($Dat,12,$Records,0,$Records.Length)
 [byte[]]$Rv=[Text.Encoding]::ASCII.GetBytes($Release);[byte[]]$HashInput=[byte[]]::new($Records.Length+$Rv.Length)
 [Array]::Copy($Records,0,$HashInput,0,$Records.Length);[Array]::Copy($Rv,0,$HashInput,$Records.Length,$Rv.Length)
 return [AmdGcfMetroHash64V3RC2]::Big([AmdGcfMetroHash64V3RC2]::Compute($HashInput,0,$false))
}
[byte[]]$Official=[IO.File]::ReadAllBytes($OfficialDatPath)
[int]$Count=[BitConverter]::ToUInt32($Official,0)
if($Count-ne 226-or$Official.Length-ne 690){throw "Official DAT shape mismatch. Count=$Count Length=$($Official.Length)"}
[byte[]]$StoredHeader=[byte[]]::new(8);[Array]::Copy($Official,4,$StoredHeader,0,8)
[byte[]]$Check=Get-Header $Official $ReleaseVersion
$HeaderMatches=$true
if($StoredHeader.Length-ne$Check.Length){$HeaderMatches=$false}else{for($j=0;$j-lt$StoredHeader.Length;$j++){if($StoredHeader[$j]-ne$Check[$j]){$HeaderMatches=$false;break}}}
if(-not$HeaderMatches){throw 'MetroHash self-test against the official DAT failed.'}
$Records=@()
for($i=0;$i-lt$Count;$i++){ $p=12+(3*$i);$off=[BitConverter]::ToUInt16($Official,$p);$key=($off-$p)-band 0xFFFF;$Records+=,[pscustomobject]@{Key=[int]$key;Value=[int]$Official[$p+2]} }
function Insert-Sorted([object[]]$Rows,[int]$Key,[int]$Value){$list=New-Object System.Collections.ArrayList;foreach($r in $Rows){[void]$list.Add($r)};$idx=$list.Count;for($i=0;$i-lt$list.Count;$i++){if($list[$i].Key-gt$Key-or($list[$i].Key-eq$Key-and$list[$i].Value-gt$Value)){$idx=$i;break}};[void]$list.Insert($idx,[pscustomobject]@{Key=$Key;Value=$Value});return ,$list.ToArray()}
if(@($Records|Where-Object{$_.Key-eq 0x15BF-and$_.Value-eq 0x04}).Count-ne0){throw 'Official DAT already contains 15BF->04.'}
if(@($Records|Where-Object{$_.Key-eq 0x15C8-and$_.Value-eq 0xC9}).Count-ne0){throw 'Official DAT already contains 15C8->C9.'}
$Records=Insert-Sorted $Records 0x15BF 0x04
$Records=Insert-Sorted $Records 0x15C8 0xC9
if($Records.Count-ne228){throw "Final DAT record count mismatch: $($Records.Count)"}
[byte[]]$Out=[byte[]]::new(12+(3*$Records.Count));[Array]::Copy([BitConverter]::GetBytes([uint32]$Records.Count),0,$Out,0,4)
for($i=0;$i-lt$Records.Count;$i++){ $p=12+(3*$i);$StoredOffset=[int]$Records[$i].Key+$p;if($StoredOffset-gt0xFFFF){throw 'DAT stored-offset overflow.'};$ob=[BitConverter]::GetBytes([uint16]$StoredOffset);$Out[$p]=$ob[0];$Out[$p+1]=$ob[1];$Out[$p+2]=[byte]$Records[$i].Value }
$Header=Get-Header $Out $ReleaseVersion;[Array]::Copy($Header,0,$Out,4,8)
$Parent=Split-Path -Parent $OutputPath;New-Item -ItemType Directory -Path $Parent -Force|Out-Null;[IO.File]::WriteAllBytes($OutputPath,$Out)
$Final=Hash $OutputPath;if($Final-ne$ExpectedFinalHash){throw "Final DAT reconstruction failed. Expected=$ExpectedFinalHash Actual=$Final"}
[pscustomobject]@{Path=$OutputPath;SHA256=$Final;Length=$Out.Length;RecordCount=$Records.Count;Exact=$true}
