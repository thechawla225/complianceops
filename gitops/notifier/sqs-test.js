const { SQSClient, ReceiveMessageCommand } = require('/tmp/node_modules/@aws-sdk/client-sqs');

const client = new SQSClient({ region: 'us-west-2' });
client.send(new ReceiveMessageCommand({
  QueueUrl: 'https://sqs.us-west-2.amazonaws.com/697961193772/complianceops-flagged-transactions',
  MaxNumberOfMessages: 1,
}))
  .then(r => console.log('SUCCESS', JSON.stringify(r, null, 2)))
  .catch(e => console.log('ERROR', e.name, '-', e.message));