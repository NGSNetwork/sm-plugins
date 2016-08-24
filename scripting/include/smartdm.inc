stock int Downloader_GetMaterialsFromMDL(const char[] model, char[][] files, int maxsize, int maxlen)
{
	if(!FileExists(model))
		return 0;

	int m_iNum = 0;

	Handle m_hFile = OpenFile(model, "rb");

	FileSeek(m_hFile, 204, SEEK_SET);
	ReadFileCell(m_hFile, m_iNum, 4);

	FileSeek(m_hFile, 0, SEEK_END);
	int m_cChar;
	int m_iPos;
	do
	{
		FileSeek(m_hFile, -2, SEEK_CUR);
		ReadFileCell(m_hFile, m_cChar, 1);
	} while (m_cChar == 0);
	FileSeek(m_hFile, 1, SEEK_CUR);
	
	char m_szPath[PLATFORM_MAX_PATH];
	do
	{
		FileSeek(m_hFile, -2, SEEK_CUR);
		ReadFileCell(m_hFile, m_cChar, 1);
	} while(m_cChar != 0);
	m_iPos = FilePosition(m_hFile);
	ReadFileString(m_hFile, m_szPath, sizeof(m_szPath));
	FileSeek(m_hFile, m_iPos, SEEK_SET);

	int m_iRet;
	char m_szFile[PLATFORM_MAX_PATH];
	for(m_iRet=0;m_iRet<m_iNum;++m_iRet)
	{
		if(m_iNum == maxsize)
			break;
		FileSeek(m_hFile, -1, SEEK_CUR);
		do
		{
			FileSeek(m_hFile, -2, SEEK_CUR);
			ReadFileCell(m_hFile, m_cChar, 1);
		} while(m_cChar != 0);
		m_iPos = FilePosition(m_hFile);
		ReadFileString(m_hFile, m_szFile, sizeof(m_szFile));
		Format(files[m_iRet], maxlen, "materials\\%s%s.vmt", m_szPath, m_szFile);
		FileSeek(m_hFile, m_iPos, SEEK_SET);
	}


	return m_iRet;
}

char g_szModelExts[][16] = {".phy", ".sw.vtx", ".dx80.vtx", ".dx90.vtx", ".vtx", ".xbox.vtx", ".vvd"};
stock int Downloader_GetModelFiles(const char[] model, char[][] files, int maxsize, int maxlen)
{
	char m_szRawPath[PLATFORM_MAX_PATH];
	strcopy(m_szRawPath, sizeof(m_szRawPath), model);
	int m_iDot = FindCharInString(m_szRawPath, '.', true);
	if(m_iDot == -1)
		return 0;
	m_szRawPath[m_iDot] = 0;

	int m_iNum = 0;
	for(int i=0;i<sizeof(g_szModelExts);++i)
	{
		if(m_iNum == maxsize)
			break;
		Format(files[m_iNum], maxlen, "%s%s", m_szRawPath, g_szModelExts[i]);
		if(FileExists(files[m_iNum]))
			++m_iNum;
	}
	return m_iNum;
}

char g_szMaterialKeys[][64] = {"$baseTexture", "$bumpmap", "$lightwarptexture"};
stock int Downloader_GetMaterialsFromVMT(const char[] vmt, char[][] materials, int maxsize, int maxlen)
{
	if(!FileExists(vmt))
		return 0;

	char m_szLine[512];

	Handle m_hFile = OpenFile(vmt, "r");
	
	bool m_bFound[sizeof(g_szMaterialKeys)];
	int m_iPos;
	int m_iLast;
	int m_iNum = 0;
	while(ReadFileLine(m_hFile, m_szLine, sizeof(m_szLine))!=false)
	{
		if(m_iNum == sizeof(g_szMaterialKeys) || maxsize == m_iNum)
			break;

		for(int i=0;i<sizeof(g_szMaterialKeys);++i)
		{
			if(m_bFound[i])
				continue;
			if((m_iPos = StrContains(m_szLine, g_szMaterialKeys[i], false)) > 0)
			{
				m_bFound[i]=true;
				while(m_szLine[m_iPos] != '"' && m_szLine[m_iPos] != ' ' && m_szLine[m_iPos] != '	')
					++m_iPos;
				while(m_szLine[m_iPos] == ' ' || m_szLine[m_iPos] == '	' || m_szLine[m_iPos] == '"')
					++m_iPos;
				m_iLast = m_iPos;
				while(m_szLine[m_iLast] != '"' && m_szLine[m_iLast] != '\r' && m_szLine[m_iLast] != '\n' && m_szLine[m_iLast] != ' ' && m_szLine[m_iLast] != '	' && m_szLine[m_iLast] != 0)
					++m_iLast;
				m_szLine[m_iLast] = 0;
				strcopy(materials[m_iNum], maxlen, m_szLine[m_iPos]);
				++m_iNum;
			}
		}
	}

	CloseHandle(m_hFile);

	return m_iNum;
}

Handle g_hCachedFiles = null;
Handle g_hCachedNums = null;
stock int Downloader_AddFileToDownloadsTable(const char[] filename)
{
	if(!FileExists(filename))
		return 0;

	if(g_hCachedNums == null)
	{
		g_hCachedNums = CreateTrie();
		g_hCachedFiles = CreateArray(PLATFORM_MAX_PATH);
	}

	AddFileToDownloadsTable(filename);

	int m_iValue;
	if(GetTrieValue(g_hCachedNums, filename, m_iValue))
	{
		int m_iStart = FindStringInArray(g_hCachedFiles, filename)+1;
		char m_szFile[PLATFORM_MAX_PATH];
		for(int i=m_iStart-m_iValue-1;i<m_iStart-1;++i)
		{
			GetArrayString(g_hCachedFiles, i, m_szFile, sizeof(m_szFile));
			AddFileToDownloadsTable(m_szFile);
		}
		return true;
	}

	char m_szExt[16];
	int m_iDot = FindCharInString(filename, '.', true);
	if(m_iDot == -1)
		return true;

	int m_iNumFiles = 0;

	strcopy(m_szExt, sizeof(m_szExt), filename[m_iDot]);
	char m_szMaterials[16][PLATFORM_MAX_PATH];
	int m_iNum;
	if(strcmp(m_szExt, ".mdl") == 0)
	{
		char m_szFiles[sizeof(g_szModelExts)][PLATFORM_MAX_PATH];
		m_iNum = Downloader_GetModelFiles(filename, m_szFiles, sizeof(m_szFiles), sizeof(m_szFiles[]));
		for(int i=0;i<m_iNum;++i)
			m_iNumFiles += Downloader_AddFileToDownloadsTable(m_szFiles[i])+1;

		
		m_iNum = Downloader_GetMaterialsFromMDL(filename, m_szMaterials, sizeof(m_szMaterials), sizeof(m_szMaterials[]));
		for(int i=0;i<m_iNum;++i)
		{
			if(FileExists(m_szMaterials[i]))
				m_iNumFiles += Downloader_AddFileToDownloadsTable(m_szMaterials[i])+1;
		}
	} else if(strcmp(m_szExt, ".vmt") == 0)
	{
		m_iNum = Downloader_GetMaterialsFromVMT(filename, m_szMaterials, sizeof(m_szMaterials), sizeof(m_szMaterials[]));
		char m_szMaterial[PLATFORM_MAX_PATH];
		for(int i=0;i<m_iNum;++i)
		{
			Format(m_szMaterial, sizeof(m_szMaterial), "materials\\%s.vtf", m_szMaterials[i]);
			if(FileExists(m_szMaterial))
				m_iNumFiles += Downloader_AddFileToDownloadsTable(m_szMaterial)+1;
		}
	}

	PushArrayString(g_hCachedFiles, filename);
	SetTrieValue(g_hCachedNums, filename, m_iNumFiles);

	return m_iNumFiles;
}