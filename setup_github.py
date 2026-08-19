import os
import re
import json
import urllib.request
import urllib.error
import subprocess

def main():
    print("🚀 بدء الإعداد التلقائي لـ GitHub...")
    
    # 1. Get the token automatically using gh cli if available
    token = os.environ.get('GITHUB_TOKEN')
    if not token:
        try:
            token = subprocess.check_output(['gh', 'auth', 'token'], text=True).strip()
            print("🔑 تم سحب رمز GitHub تلقائياً من إعدادات جهازك.")
        except Exception:
            pass
            
    if not token:
        token = input("🔑 أدخل رمز GitHub (Personal Access Token) الخاص بك: ").strip()

    if not token:
        print("❌ لم يتم إدخال الرمز. فشل الإعداد.")
        return

    # GitHub API URLs
    api_base = "https://api.github.com"
    repo_name = "rafeeq-api"
    
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json"
    }

    # 2. Get username
    print("👤 جاري التحقق من الحساب...")
    try:
        req = urllib.request.Request(f"{api_base}/user", headers=headers)
        with urllib.request.urlopen(req) as response:
            user_data = json.loads(response.read().decode('utf-8'))
            username = user_data['login']
            print(f"✅ مرحباً بك: {username}")
    except Exception as e:
        print(f"❌ فشل التحقق من الرمز: {e}")
        return

    # 3. Create repository if not exists
    print(f"📦 جاري إنشاء مستودع '{repo_name}'...")
    try:
        data = json.dumps({"name": repo_name, "private": False, "description": "APIs and Configs for Rafeeq Al-Darb App"}).encode('utf-8')
        req = urllib.request.Request(f"{api_base}/user/repos", data=data, headers=headers)
        with urllib.request.urlopen(req) as response:
            print("✅ تم إنشاء المستودع بنجاح!")
    except urllib.error.HTTPError as e:
        if e.code == 422: # Repo already exists
            print("ℹ️ المستودع موجود مسبقاً.")
        else:
            print(f"❌ فشل إنشاء المستودع: {e}")
            return

    # 4. Read rafeeq_config.json
    config_path = "rafeeq_config.json"
    if not os.path.exists(config_path):
        print(f"❌ ملف {config_path} غير موجود.")
        return
        
    with open(config_path, "rb") as f:
        file_content = f.read()

    import base64
    b64_content = base64.b64encode(file_content).decode('utf-8')

    # 5. Check if file exists in repo to get its SHA (for updating)
    print("📤 جاري رفع ملف الإعدادات...")
    file_url = f"{api_base}/repos/{username}/{repo_name}/contents/{config_path}"
    sha = None
    try:
        req = urllib.request.Request(file_url, headers=headers)
        with urllib.request.urlopen(req) as response:
            file_data = json.loads(response.read().decode('utf-8'))
            sha = file_data['sha']
    except urllib.error.HTTPError as e:
        if e.code != 404:
            print(f"❌ فشل جلب حالة الملف: {e}")
            return

    # 6. Upload/Update file
    put_data = {
        "message": "Update Rafeeq config APIs",
        "content": b64_content,
        "branch": "main"
    }
    if sha:
        put_data["sha"] = sha
        
    try:
        data = json.dumps(put_data).encode('utf-8')
        req = urllib.request.Request(file_url, data=data, headers=headers, method='PUT')
        with urllib.request.urlopen(req) as response:
            print("✅ تم رفع الملف بنجاح!")
    except Exception as e:
        print(f"❌ فشل رفع الملف: {e}")
        return

    # 7. Update github_config_service.dart
    raw_url = f"https://raw.githubusercontent.com/{username}/{repo_name}/main/{config_path}"
    print(f"🔗 الرابط المباشر: {raw_url}")
    
    dart_file = os.path.join("lib", "core", "services", "github_config_service.dart")
    print(f"📝 جاري تحديث التطبيق ليرتبط بالرابط الجديد...")
    if os.path.exists(dart_file):
        with open(dart_file, "r", encoding="utf-8") as f:
            content = f.read()
            
        # Regex to replace the URL
        new_content = re.sub(r"const _githubConfigUrl = '.*?';", f"const _githubConfigUrl = '{raw_url}';", content)
        
        with open(dart_file, "w", encoding="utf-8") as f:
            f.write(new_content)
        print("✅ تم ربط التطبيق بحسابك بنجاح!")
    else:
        print(f"❌ لم يتم العثور على ملف {dart_file}")

    print("\n🎉 تمت العملية بنجاح. التطبيق الآن يقرأ من حسابك على GitHub!")

if __name__ == "__main__":
    main()
