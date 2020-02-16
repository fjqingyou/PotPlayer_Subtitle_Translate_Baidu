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


//必须配置的部分，不过现在已经移交到“实时字幕翻译”中了
//它的位置是： 打开任意视频或者点击左上角的PolPlayer -> 字幕 -> 实时字幕翻译 -> 实时字幕翻译设置 -> 选中百度翻译 -> 点右边的 “账户设置”
string appId = "";//appid
string toKey = "";//密钥

//可选配置，一般而言是不用修改的！
int coolTime = 1000;//冷却时间，这里的单位是毫秒，1秒钟=1000毫秒，如果提示 error:54003, 那么就加大这个数字，建议一次加100
string userAgent = "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36";//这个是可选配置，一般不用修改！

//执行环境，请不要修改！
int NULL = 0;
int executeThreadId = NULL;//这个变量的命名是我的目标，不过，暂时没能实现!只是做了个还有小bug的临时替代方案
int nextExecuteTime = 0;//下次执行代码的时间


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
	return "请输入配置";
}

string GetLoginDesc(){
	return "请输入AppId和密钥！";
}


string GetUserText(){
	return "App ID:";
}

string GetPasswordText(){
	return "密钥:";
}


array<string> GetSrcLangs(){
	array<string> ret = GetLangTable();
	
	ret.insertAt(0, ""); // empty is auto
	return ret;
}

array<string> GetDstLangs(){
	return GetLangTable();
}

string ServerLogin(string appIdStr, string toKeyStr){
	if (appIdStr.empty() || toKeyStr.empty()) return "fail";
	appId = appIdStr;
	toKey = toKeyStr;
	return "200 ok";
}


string Translate(string text, string &in srcLang, string &in dstLang){
	string ret = "";
	if(!text.empty()){//确实有内容需要翻译才有必要继续
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

		//线程同步 - 独占锁
		acquireExclusiveLock();

		//计算冷却时间，应百度翻译新版API要求，加入频率设定
		int tickCount = HostGetTickCount();
		int sleepTime = nextExecuteTime - tickCount;

		// HostPrintUTF8("tickCount == " + tickCount + " sleepTime == " + sleepTime);// for debug

		if(sleepTime > 0){//如果冷却时间还没到，有需要休息的部分
			HostSleep(sleepTime);//那么就休息这些时间
		}

		
		// HostPrintUTF8("url == " + url);// for debug
		string html = HostUrlGetString(url, userAgent);

		//更新下次执行任务的时间
		nextExecuteTime = coolTime + HostGetTickCount();//上面 HostUrlGetString 需要时间执行，所以需要重新获取 TickCount

		//线程同步 - 释放独占锁
		releaseExclusiveLock();

		if(!html.empty()){//如果成功取得 Html 内容
			ret = JsonParse(html);//那么解析这个 HTML 里面的 json 内容
		}

		if(text == ret){//如果翻译后的译文，跟原文一致
			if (srcLang == "zh" && dstLang == "cht"){}      // 简体 转 繁体
			else if (srcLang == "cht" && dstLang == "zh"){} // 繁体 转 简体
			else
				ret = " ";//那么忽略这个字幕
		}

		if (ret.length() > 0){//如果有翻译结果
			srcLang = "UTF8";
			dstLang = "UTF8";
		}
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
					for(int i = 0; i < transResult.size(); i++){
						JsonValue item = transResult[i];//取得翻译结果
						JsonValue dst = item["dst"];//获取翻译结果的目标
						if(i > 0){//如果需要处理多行的情况
							ret += "\n";//第二行开始的开头位置，加上换行符
						}
						ret += dst.asString();//拼接翻译结果，可能存在多行
					}
				}
			}
		}
	} 
	return ret;
}

/**
上独占锁 - 当前仅仅只是模拟版，还有 bug ,不过暂时可临时使用
*/
void acquireExclusiveLock(){
	int tickCount1 = HostGetTickCount();//取得第一个时刻
	HostSleep(1);
	int tickCount2 = HostGetTickCount();//取得第二个时刻
	/**
	注意：
	1、这是一个临时的方案
	2、因为我本地尝试：HostLoadLibrary("Kernel32.dll") 没能正常工作，所以才采用当前这个临时方案
	3、key 原本应该是唯一的，不然可能存在多个线程得到的是同一个tickCount。会导致多个线程同时执行，意味着这多个线程只能成功一个翻译，虽然已经做了部分防御，但是不能确保万一！
	4、当然，上方的触发的概率不高，不过确实存在这个bug。
	5、所以当前只能作为临时方案，有更好的方案时，必须替换掉
	*/
	int key = tickCount1 << 16 + (tickCount2 & 0xFFFF);//两个时刻合并，使得多线程重复相同数字的概率下降，但还是有可能重复，当前这个算法，仅仅能作为临时的解决方案而已！

	while(executeThreadId != key){
		if(executeThreadId == NULL){//如果没其他任务在执行了
			executeThreadId = key;//尝试注册当前任务为执行任务
		}

		HostSleep(1);//休息下，看看有没有抢着注册的其他线程任务，或者等待正在执行的任务解除锁

		if(executeThreadId == key){//如果没被其他线程抢注册了
			HostSleep(1);//再次休息下
			if(executeThreadId == key){//二次确认，确保原子性
				break;//成功抢到执行权限，不必再等待了
			}
		}
	}
}

/**
释放独占锁 - 当前仅仅只是模拟版，还有 bug ,不过暂时可临时使用
*/
void releaseExclusiveLock(){
	executeThreadId = NULL;//解除锁
}
