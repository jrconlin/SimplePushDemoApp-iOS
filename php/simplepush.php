<?php

// Put your device token here (without spaces):
$deviceToken = 'a8cb07bea690e4f0d7fa9168d85e69ca99a12337ba799a738ceba17c532a157f';

// Put your private key's passphrase here:
$passphrase = '';
$push_v0 = false;
$push_v2 = true;

////////////////////////////////////////////////////////////////////////////////

$ctx = stream_context_create();
stream_context_set_option($ctx, 'ssl', 'local_cert', 'ck.pem');
stream_context_set_option($ctx, 'ssl', 'passphrase', $passphrase);

// Open a connection to the APNS server
$fp = stream_socket_client(
	'ssl://gateway.sandbox.push.apple.com:2195', $err,
	$errstr, 60, STREAM_CLIENT_CONNECT|STREAM_CLIENT_PERSISTENT, $ctx);

if (!$fp)
	exit("Failed to connect: $err $errstr" . PHP_EOL);

echo 'Connected to APNS' . PHP_EOL;


// Create the payload body
$body['aps'] = array(
    'alert' => array (
        // Uncomment these lines if you want to see the notification pop.
//        'title' => 'SimplePush Demo v0',
//        'body' => 'Push v0 succeeded!',
        'action-loc-key' => 'Open',
        'content-available'=> 1
    ),
    'sound' => 'default',
    // set to 1 for "silent" notifications (in theory).
    'content-available'=> 1
);
// extra data visible only to the app.
$body['version'] = 123;
$body['data'] = 'foobar';


if ($push_v0) {
    // Encode the payload as JSON
    $payload = json_encode($body);
    print $payload."\n";
    $result = false;

    // Build the binary notification
    // v0

    $frame = chr(0) . pack('n', 32) . pack('H*', $deviceToken) . pack('n', strlen($payload)) . $payload;
    $result = fwrite($fp, $frame, strlen($frame));
    if (!$result) {
        print "Version 0 push failed. ".bin2hex($result). "\n";
        exit();
    }
}
// Build the binary notification for v2
if ($push_v2) {
    // Again, uncomment if you want the notification pop
    //$body['aps']['alert']['title'] = "SimplePush Demo v2";
    //$body['aps']['alert']['body'] = "SimplePush Demo v2 succeeded";

    //tweak the "data" so it's different than the v0 one.
    $body['data'] = $body['data'] . " - " . time();
    $payload = json_encode($body);

    $msg = "";
    // chr = 8 bit
    // pack n = 16 bit
    // pack N = 32 bit
    $item = chr(1) . pack('n', 32) . pack('H*', $deviceToken);
    print "\n".bin2hex($item);
    $msg .= $item;

    $item = chr(2) . pack('n', strlen($payload)) . $payload;
    print "\n".bin2hex($item);
    $msg .= $item;

    $item = chr(3) . pack('n', 4) . pack('N', time());
    print "\n".bin2hex($item);
    $msg .= $item;

    $item = chr(4) . pack('n', 4) . pack('N', time() + 60);
    print "\n".bin2hex($item);
    $msg .= $item;

    $item = chr(5) . pack('n', 1) . chr(10);
    print "\n".bin2hex($item);
    $msg .= $item;

    // build the wrapper frame:
    $frame = chr(2) . pack('N', strlen($msg)) . $msg;
    print "\nFrame:\n";
    var_dump($frame);
    print "\n".bin2hex($frame)."\n";

    // Send it to the server
    $result = fwrite($fp, $frame, strlen($frame));
    print "\n";

    if (!$result)
        echo "v2 not delivered\n" . bin2hex($result). "\n";
    else
        echo "v2 successfully delivered\n";
}

// Close the connection to the server
fclose($fp);
