
module.exports = {
    hello: function(name) {
        console.log("Hello, " + name);
    },
    bye: function(name) {
        console.log("Goodbye, " + name);
    },
    callTestFunc: function() {
        testFunction();
    },
};

function callTest() {
    testFunction();
}

