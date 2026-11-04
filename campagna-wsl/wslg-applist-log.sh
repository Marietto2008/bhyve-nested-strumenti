grep -i -e rdpapplist -e 'app_list_monitor_thread: running' -e notify_app_list /tmp/wslg-runtime/weston.log | head; ls -l /usr/local/wslg/lib/ | grep -i applist
