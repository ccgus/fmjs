module.exports = {
    hello: function(name) {
        console.log("Hello, " + name);
    },
    bye: function(name) {
        console.log("Goodbye, " + name);
    },
    callTestFunc: function() {
        //print("This is the test funk");
        testFunction();
    },
    someVal: 0,
    callInc: function () {
        //print("Calling callInc! Currently at " + this.someVal)
        this.someVal = this.someVal + 1;
        return this.someVal;
    }
};
