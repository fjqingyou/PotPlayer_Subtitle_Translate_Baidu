/*
	real time subtitle translate for PotPlayer using Bai Du API
*/

// string GetTitle() 														-> get title for UI
// string GetVersion														-> get version for manage
// string GetDesc()															-> get detail information
// string GetLoginTitle()													-> get title for login dialog
// string GetLoginDesc()													-> get desc for login dialog
// string ServerLogin(string User, string Pass)								-> login
// string ServerLogout()													-> logout
// array<string> GetSrcLangs() 												-> get source language
// array<string> GetDstLangs() 												-> get target language
// string Translate(string Text, string &in SrcLang, string &in DstLang) 	-> do translate !!

//必须配置的部分
string appId = "XXXXXXXXXXXXXXXXXXX";//appid
string toKey = "XXXXXXXXXXXXXXXXXXX";//密钥

string GetVersion(){
	return "1";
}

string GetTitle(){
	return "{$CP950=Bai Du 翻譯$}{$CP0=Bai Du translate$}";
}


string GetDesc(){
	return "https://fanyi.baidu.com/";
}

string GetLoginTitle(){
	return "";
}

string GetLoginDesc(){
	return "";
}

array<string> GetSrcLangs(){
	array<string> ret = GetLangTable();
	
	ret.insertAt(0, ""); // empty is auto
	return ret;
}

array<string> GetDstLangs(){
	return GetLangTable();
}


string userAgent = "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36";



string Translate(string text, string &in srcLang, string &in dstLang){
	string ret = "";

	//开发文档。需要App id 等信息
	//http://api.fanyi.baidu.com/api/trans/product/apidoc
	// HostOpenConsole();	// for debug
	
	//语言选择
	srcLang = GetLang(srcLang);
	dstLang = GetLang(dstLang);
	
	
//	API.. Always UTF-8
	string q = HostUrlEncode(text);
	
	string salt = "" + HostGetTickCount();//随机数
	string sign = HostHashMD5(appId + text + salt + toKey);//签名 appid+q+salt+密钥
	string parames = "from=" + srcLang + "&to=" + dstLang + "&appid=" + appId + "&sign=" + sign  + "&salt=" + salt + "&q=" + q;
	string url = "http://api.fanyi.baidu.com/api/trans/vip/translate?" + parames;

	// HostPrintUTF8("url == " + url);// for debug
	string html = HostUrlGetString(url, userAgent);

	if(!html.empty()){
		ret = JsonParse(html);
	}

	if (ret.length() > 0){
		srcLang = "UTF8";
		dstLang = "UTF8";
	}	

	if(text == ret){//如果翻译后的译文，跟原文一致
		ret = "";//那么忽略这个字幕
	}
	return ret;
}

//获取语言
string GetLang(string &in lang){
	string result = lang;

	if(result.empty()){//空字符串
		result = "auto";
	} else if(result == "zh-CN"){//简体中文
		result = "zh";
	} else if(result == "zh-TW"){//繁体中文
		result = "cht";
	} else if(result == "ja"){//日语
		result = "jp";
	} else if(result == "ro"){//罗马尼亚语
		result = "rom";
	}

	return result;
}


array<string> langTable = {
	"zh-CN",//->zh
	"zh-TW",//->cht
	"en",
	"ja",//->jp
	"kor",
	"fra",
	"spa",
	"th",
	"ara",
	"ru",
	"pt",
	"de",
	"it",
	"el",
	"nl",
	"pl",
	"bul",
	"est",
	"dan",
	"fin",
	"cs",
	"ro",//->rom
	"slo",
	"swe",
	"hu",
	"vie"
	"yue",//粤语
	"wyw",//文言文
};

//获取支持语言
array<string>  GetLangTable(){
	return langTable;
}

//解析Json数据
string JsonParse(string json){
	string ret = "";//返回值
	JsonReader reader;
	JsonValue root;
	
	if (reader.parse(json, root)){//如果成功解析了json内容
		if(root.isObject()){//要求是对象模式
			bool hasError = false;
			array<string> keys = root.getKeys();//获取json root对象中所有的key

			//查找是否存在错误
			for(uint i = 0; i < keys.size(); i++){
				if("error_code" == keys[i]){
					hasError = true;
					break;
				}
			}

			if(hasError){//如果发生了错误
				JsonValue errorCode = root["error_code"];//错误编号
				JsonValue errorMsg = root["error_msg"];//错误信息描述
				ret = "error: " + errorCode.asString() + ", error_msg=" + errorMsg.asString();
			}else{//如果没发生错误
				JsonValue transResult = root["trans_result"];//取得翻译结果
				if(transResult.isArray()){//如果有翻译结果-必须是数组形式
					for(uint i = 0; i < transResult.size(); i++){
						JsonValue item = transResult[i];//取得翻译结果
						JsonValue dst = item["dst"];//获取翻译结果的目标
						if(i > 0){//如果需要处理多行的情况
							ret += "\N";//第二行开始的开头位置，加上换行符
						}
						ret += dst.asString();//拼接翻译结果，可能存在多行
					}
				}
			}
		}
	} 
	return ret;
}
