$.extend(SockJS.prototype, EventEmitter.prototype)
var sock = window.sock = new SockJS(window.location.href+"chat");
sock.onopen = function() {
  console.log("open");
  this.emit('open')
};

sock.onmessage = function(e) {
  console.log("message", e.data);
  var data = JSON.parse(e.data);
  this.emit('data', data);
  if(data.event){
    this.emit(data.event, data);
  }
};

sock.onclose = function() {
  this.emit('close');
};
window.onbeforeunload = function(){
  sock.onclose = function () {};
  sock.close();
};
sock.send_data = function(data){
  this.send(JSON.stringify(data))
}