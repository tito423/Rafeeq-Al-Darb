import boto3

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

paginator = s3.get_paginator('list_objects_v2')
total_size = 0
total_count = 0
top_level = {}
page_num = 0
for page in paginator.paginate(Bucket='rafeeq-aldarb-data', PaginationConfig={'PageSize': 1000}):
    page_num += 1
    contents = page.get('Contents', [])
    for obj in contents:
        total_size += obj['Size']
        total_count += 1
        top = obj['Key'].split('/')[0]
        top_level[top] = top_level.get(top, 0) + obj['Size']
    print(f'page {page_num}: +{len(contents)} objs, running total {total_count}', flush=True)

print('TOTAL_COUNT:', total_count)
print('TOTAL_SIZE_BYTES:', total_size)
print('TOTAL_SIZE_GB:', round(total_size / (1024**3), 2))
print('--- by top-level prefix ---')
for k, v in sorted(top_level.items(), key=lambda x: -x[1]):
    print(f'{k}: {round(v/(1024**2),1)} MB  ({[kk for kk in top_level][:0]})')
