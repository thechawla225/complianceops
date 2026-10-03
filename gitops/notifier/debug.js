const https = require('https');
const fs = require('fs');

const token = fs.readFileSync('/var/run/secrets/eks.amazonaws.com/serviceaccount/token', 'utf8').trim();
const role = encodeURIComponent('arn:aws:iam::697961193772:role/complianceops-notifier-sqs-role');
const tok = encodeURIComponent(token);
const path = `/?Action=AssumeRoleWithWebIdentity&Version=2011-06-15&RoleArn=${role}&RoleSessionName=debug&WebIdentityToken=${tok}`;

https.get({ hostname: 'sts.us-west-2.amazonaws.com', path }, res => {
  let data = '';
  res.on('data', c => data += c);
  res.on('end', () => {
    console.log('STATUS', res.statusCode);
    console.log(data);
    process.exit(0);
  });
}).on('error', e => {
  console.log('ERR', e.message);
  process.exit(1);
});