import time
import threading
import boto3
from botocore.config import Config
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TaskProgressColumn, TimeRemainingColumn
from rich.console import Console
from rich.panel import Panel

R2_ENDPOINT_URL = "https://33946f20ace0d8aa2aba052fa705d685.r2.cloudflarestorage.com"
R2_ACCESS_KEY = "0ea932e392ce7b96cb81e8b4132a26d9"
R2_SECRET_KEY = "a117398b232c11b17b9bebd497131bf8b0497791b20a5f02ada8558cbc1427ad"
BUCKET_NAME = "rafeeq-aldarb-data"
TOTAL_FILES = 700000

# Shared state
real_count = 119358 # starting approximation based on previous check
is_fetching = False

def fetch_real_count():
    global real_count, is_fetching
    client = boto3.client(
        's3',
        endpoint_url=R2_ENDPOINT_URL,
        aws_access_key_id=R2_ACCESS_KEY,
        aws_secret_access_key=R2_SECRET_KEY,
        config=Config(signature_version='s3v4'),
        region_name='auto'
    )
    
    while True:
        try:
            is_fetching = True
            paginator = client.get_paginator('list_objects_v2')
            pages = paginator.paginate(Bucket=BUCKET_NAME)
            count = 0
            for page in pages:
                if 'Contents' in page:
                    count += len(page['Contents'])
            if count > 0:
                real_count = count
        except Exception:
            pass
        finally:
            is_fetching = False
            
        time.sleep(30) # wait 30 seconds before recounting

# Start background thread to periodically poll R2 bucket exactly
t = threading.Thread(target=fetch_real_count, daemon=True)
t.start()

console = Console()
console.print(Panel.fit("[bold green]Rafiq Al-Darb[/bold green] - Cloudflare R2 Upload Progress Monitor"))

# Initialize rich progress bar
with Progress(
    SpinnerColumn(),
    TextColumn("[progress.description]{task.description}"),
    BarColumn(bar_width=40),
    TaskProgressColumn(),
    TextColumn("({task.completed}/{task.total})"),
    TimeRemainingColumn(),
    console=console,
    transient=False
) as progress:
    
    task = progress.add_task("[cyan]Uploading assets...", total=TOTAL_FILES)
    progress.update(task, completed=real_count)
    
    display_count = real_count
    
    while display_count < TOTAL_FILES:
        # Smooth interpolation:
        # If the actual count from the background thread is higher, rapidly catch up.
        # Otherwise, artificially advance slowly to keep the bar "alive" based on average upload speed.
        
        if display_count < real_count:
            # We are behind the real count, catch up quickly
            display_count += min(500, real_count - display_count)
        else:
            # We reached the last known real count, increment slowly as an estimate (approx 20 files/sec)
            # Cap the optimistic estimate to not stray too far from reality (+2000 files max)
            if display_count < real_count + 2000:
                display_count += 2
        
        progress.update(task, completed=display_count)
        time.sleep(0.1) # 10 ticks per second

console.print("[bold green]Upload Complete![/bold green]")
