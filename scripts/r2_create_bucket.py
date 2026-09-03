import boto3
from botocore.exceptions import ClientError

env = {}
with open(r'E:\My Projects\Rafiq-Al-Darb\scripts\.env') as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith('#') and '=' in line:
            k, v = line.split('=', 1)
            env[k] = v

s3 = boto3.client('s3',
    endpoint_url=env['R2_ENDPOINT'],
    aws_access_key_id=env['R2_ACCESS_KEY_ID'],
    aws_secret_access_key=env['R2_SECRET_ACCESS_KEY'],
    region_name='auto')

bucket = 'rafeeq-content'
try:
    s3.create_bucket(Bucket=bucket)
    print(f'created bucket: {bucket}')
except ClientError as e:
    print('ClientError:', e.response.get('Error'))
except Exception as e:
    print('Error:', repr(e))

resp = s3.list_buckets()
print('buckets now:', [b['Name'] for b in resp.get('Buckets', [])])
