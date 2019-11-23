/*
Game Logic Notes -  The weakest of previous gen is replaced by the child of the strongest of the last generation (CONSUMERS)
                    Strength is measured by total wealth

                    End generation when time is up OR when all producers have been filled (i.e. the producersX is only nulls)

                    TO-DO:
                        - Add trade and barter logic
                        - Impact strength based on if trade successful in last generation
                        - Store trait variables and produce graphs in stats screen


*/

final float windowSizeMultiplier = 1;
final int SEED = random(1000)+1;
final float epsilon = 6;
boolean SHOW_RADIUS = false;

int windowWidth = 1920;
int windowHeight = 1080;

int CONSUMERS = 10, PRODUCERS = 10;
int prds = 0, cons = 0;
int [] producersX = new int[PRODUCERS];
int [] producersY = new int[PRODUCERS];

boolean [] consumersSAT = new boolean[CONSUMERS];

PFont font;
PGraphics screenImage;

PImage mainMenuPNG;
PImage simBG;
PImage producerPNG;
PImage consumerPNG;
PImage consumer_leftPNG;
PImage consumer_rightPNG;

int FRAMES = 60;
int menu = 100;
int score = 0;
int GENERATION = 0;
int CURR_TICK = 0;
int GENERATION_TIME = 10 * FRAMES;   // 10 second generation time

// ---------- STATISTICS DATA ----------
ArrayList consWealthHistory = new ArrayList();
ArrayList prodWealthHistory = new ArrayList();

int fontSize = 0;
int[] fontSizes = {
  50, 36, 25, 20, 16, 14, 11, 9
};

Consumer [] currentGenConsumers = new Consumer[CONSUMERS];
int consPtr = 0;
Producer [] currentGenProducers = new Producer[PRODUCERS];
int prdsPtr = 0;


/*
================================ CONSUMER ================================
GOAL :    End up with maximum value at the end of day by bartering and trading
TRAITS :  Sense - radius of vision to spot a producer, a function of wealth - but everyone has a birth sense that is immutable
          Speed - Movement speed, a combination of speedX and speedY
          reservationPrice - Maximum consumer is willing to pay for the product
          risk - Risk averse, risk neutral, risk taking


*/
class Consumer{
  // traits
  private float reservationPrice;
  int speedX;
  int speedY;
  int sense;
  int risk;   // AVERSE = 0   NEUTRAL = 1   LOVING = 2

  private boolean sat;
  private float amountOwned;
  private float wealth;
  int UUID;
  int size;
  int x, y;
  int r, g, b;
  color colour;
  float rand;
  boolean MOVING;
  int prodX, prodY;
  boolean left;
  int switchLegs;

  int birthSpeedX, birthSpeedY;
  Producer seller;


  // PARENT CONSTRUCTOR CLASS - 1st Generation
  Consumer(int UUID){
    // not satisfied for the current cycle
    this.sat = false;
    // start with no product owned
    this.amountOwned = 0;
    // self starter, started from the bottom
    this.wealth = random(29)+1;         // max = 30   min = 1
    this.size = (this.wealth/2)+50;     // max = 65     min = 50.5 radius
    this.seller = null;

    // -=- TRAITS -=-
    this.risk = random(3);      
    // should be a function of wealth and risk
    this.reservationPrice = random(20,30) + random(5,10)*(2-this.risk);     // E[p] = 25 + 7.5*risk = 32.5 for neutral
    this.speedX = int(random(-5,5));          // max = 8   min = -8
    this.birthSpeedX = speedX;
    this.speedY = int(random(-5,5));          // max = 8   min = -8
    this.birthSpeedY = speedY;
    this.sense = random(150)+100+size;  // max = 305    min = 150.5
    
    this.UUID = UUID
    this.x = random(((((windowWidth-200)/(CONSUMERS+1)))*UUID)+100, ((((windowWidth-200)/(CONSUMERS+1)))*(UUID+1))+100);
    this.y = random(windowHeight-200, windowHeight-150);
    this.r = random(50, 200);
    this.g = int(random(50, 255));
    this.b = random(50, 250);
    this.colour = color(r,g,b);
    this.MOVING = true;
    consumersSAT[this.UUID] = this.sat;
    this.left = false;
    this.switchLegs = 0;


  }

  // CHILD CONSTRUCTOR CLASS
  Consumer(int UUID, float reservationPrice, int parentWealth, int parentRisk, int speedX, int speedY, int sense, int r, int g, int b){
    this.sat = false;
    // start with no product owned
    this.amountOwned = 0;
    // inherit parent's wealth
    this.wealth = random(parentWealth/2, 3*parentWealth/2);
    this.size = (this.wealth/2)+50;
    this.seller = null;

    // -=- TRAITS -=-
    float temp = random(0,1);
    int [] risks = new int[2];
    int j = 0;
    for(int i = 1; i < 3; i++){
      if(i != parentRisk){
        risks[j] = i;
        j++;
      }
    }
    if(temp < 0.7){
      this.risk = parentRisk;
    } else if(temp < 0.85) {
      this.risk = risks[0];
    } else if(temp < 1.0) {
      this.risk = risks[1];
    }    
    // should be a function of wealth and risk
    this.reservationPrice = random(-3,3) + (reservationPrice-7.5) + random(5,10)*(2-this.risk);
    this.speedX = int(random(-2,2)) + speedX;
    this.birthSpeedX = speedX;
    this.speedY = int(random(-2,2)) + speedY; 
    this.birthSpeedY = speedY;
    this.sense = random(-30, 30) + sense;
    
    this.UUID = UUID
    this.x = random(((((windowWidth-200)/(CONSUMERS+1)))*UUID)+100, ((((windowWidth-200)/(CONSUMERS+1)))*(UUID+1))+100);
    this.y = random(windowHeight-200, windowHeight-150);
    this.r = r;
    this.g = g;
    this.b = b;
    this.colour = color(r,g,b);
    this.MOVING = true;
    consumersSAT[this.UUID] = this.sat;
    this.left = false;
    this.switchLegs = 0;
  }

  // current logic : if below res price, accept; else pick random b/w 0 and res
  int barter(float givenPrice){
    if(givenPrice < this.reservationPrice){
      return givenPrice;
    } else {
      return random(0, reservationPrice);
    }
  }

  // measure of consumer strength
  float total_wealth(){
    return (this.wealth + (this.amountOwned*this.reservationPrice));    // may be biased b/c reservationPrice includes risk
  }

  int check_range() {
    for(int i = 0; i <= prds; i++){
      if(producersX != null){
        if(distance(this.x,producersX[i],this.y,producersY[i]) <= sense){
          return i;
        }
      }
    }
    return -1;
  }

  void move(){
    if(!MOVING || (abs(this.x - this.prodX) <= epsilon && abs(this.y - this.prodY) <= epsilon)){
      consumersSAT[this.UUID] = true;
      return;
    }
    // println(producersX);

    if(!this.sat){
      rand = random(0,1);
      if(rand > 0.97){random_walk();}
      
      int chk = check_range();
      if(chk != -1){
        // FOUND SELLER, now need to barter -
        this.seller = currentGenProducers[chk];
        if(this.seller.get_available){
          // seller has material to sell - continue
          float prpsdOffer = -1;
          float backOffer = -2;
          int backAndForth = 0;
          while(prpsdOffer != backOffer){
            if(backAndForth >= 5){
              break;
            }
            prpsdOffer = random(0,min(this.reservationPrice,this.wealth));
            backOffer = this.seller.barter(prpsdOffer);
            backAndForth++;
          }
          
          if(prpsdOffer == backOffer){
            // agreement reached! - update all as necessary
            this.sat = true;
            this.prodX = producersX[chk];
            this.prodY = producersY[chk];
            producersY[chk] = null;
            producersX[chk] = null;
            int tempMult = (abs(speedX)+abs(speedY))/2;
            this.speedX = this.prodX - this.x;
            this.speedY = this.prodY - this.y;
            int div = sqrt(pow(speedX,2)+pow(speedY,2));
            this.speedX = tempMult*this.speedX/div;
            this.speedY = tempMult*this.speedY/div;

            this.wealth -= prpsdOffer;
            this.amountOwned++;
            this.seller.deal_made(backOffer, this);
          }

        }
      }
      
    }

    // move
    x += speedX;
    y += speedY;

    // bounce logic
    if (x > windowWidth){
			x = width;
			speedX *= -1;
		} if (y > windowHeight){
			y = height;
			speedY *= -1;
		} if (x < 0){
			x = 0;
			speedX *= -1;
		} if (y < windowHeight/2 - 220){
			y = windowHeight/2 - 220;
			speedY *= -1;
		}

	}

  // add angle change
  void random_walk(){
    rand = random(0,1);
    if      (rand < 0.25){speedX = -random(speedX-0.5,speedX+0.5);}
    else if (rand < 0.50){speedX = random(speedX-0.5,speedX+0.5);}
    else if (rand < 0.75){speedY = -random(speedY-0.5,speedY+0.5);}
    else if (rand < 1.00){speedY = random(speedY-0.5,speedY+0.5);}
  }

  private void stop(){
    this.MOVING = false;
  }

  void display(){
    if(SHOW_RADIUS){
      noFill();
      stroke(255);
      ellipse(x,  y,  int(this.sense),  int(this.sense));
    }
    noStroke();
    fill(r, g, b);
		// ellipse(x,  y,  size,  size);
    if(menu == 200 || this.sat){
      image(consumerPNG, x-48, y-49);
    }
    else if(menu == 201 && left){
      switchLegs++;
      if(switchLegs > FRAMES){
        image(consumer_leftPNG, x-48, y-49); 
        left = false;
        switchLegs = 0;
      } else {
        image(consumer_rightPNG, x-48, y-49);
      }
    }
    else if(menu == 201 && !left){
      switchLegs++;
      if(switchLegs > FRAMES){
        image(consumer_rightPNG, x-48, y-49); 
        left = true;
        switchLegs = 0;
      } else {
        image(consumer_leftPNG, x-48, y-49); 
      }
    }
    fill(255);
    text(UUID, x, y);
	}

  private void set_wealth(float w){
    this.wealth = w;
  }

  float get_reservationPrice(){
    return this.reservationPrice;
  }
  float get_wealth(){
    return this.wealth;
  }
  int get_risk(){
    return this.risk;
  }
  int [] get_speed(){
    return [birthSpeedX, birthSpeedY];
  }
  int get_sense(){
    return this.sense;
  }
  int [] get_colors(){
    return [this.r, this.g, this.b];
  }

  void reset_for_next_gen(){
    this.x = random(((((windowWidth-200)/(CONSUMERS+1)))*UUID)+100, ((((windowWidth-200)/(CONSUMERS+1)))*(UUID+1))+100);
    this.y = random(windowHeight-200, windowHeight-150);
    this.prodX = null;
    this.prodY = null;
    this.MOVING = true;
    this.sat = false;
    consumersSAT[this.UUID] = this.sat;
    this.speedX = birthSpeedX;
    this.speedY = birthSpeedY;
    this.seller = null;
  }

}


/*
================================ PRODUCER ================================

*/
class Producer{
  private float reservationPrice;
  // private boolean sat;
  private int amountOwned;
  private float wealth;
  int UUID;
  int size;
  public int x, y;
  int r, g, b;

  Consumer buyer;

  Producer(int UUID){
    // this.sat = false;
    this.amountOwned = random(5)+2;
    this.wealth = 0;
    // function of supply
    this.reservationPrice = amountOwned;
    this.UUID = UUID;
    this.size = 50;
    this.x = random(((((windowWidth-200)/(CONSUMERS+1)))*UUID)+100, ((((windowWidth-200)/(CONSUMERS+1)))*(UUID+1))+100);
    this.y = random(windowHeight/2 - 150, windowHeight/2 - 180);
    this.r = random(0);
    this.g = random(0);
    this.b = random(150, 255);
    this.buyer = null;
  }

  boolean get_available(){
    return this.amountOwned > 0;
  }

  // current logic : if below res price, accept; else pick random b/w 0 and res
  int barter(float givenPrice){
    if(givenPrice > this.reservationPrice){
      return givenPrice;
    } else {
      return random(reservationPrice, 3*reservationPrice);
    }
  }

  float total_wealth(){
    return (this.wealth + (this.amountOwned*this.reservationPrice));
  }

  void deal_made(float price, Consumer buyer){
    this.buyer = buyer;
    this.wealth += price;
    this.amountOwned--;
  }

  void display(){
		noStroke();
		// fill(r, g, b);
		// ellipse(x,  y,  size,  size);
    image(producerPNG, x-58, y-59);
    fill(255);
    text(UUID, x-10, y-4);
	}

  private void set_wealth(float w){
    this.wealth = w;
  }

}



// ================================ HELPER FUNCTIONS ================================
int distance(x1, x2, y1, y2) {
  return sqrt(pow(x2-x1,2)+pow(y2-y1,2));
}

void setMenu(int m) {
  menu = m;
  draw();
}

void gameOver() {
  setMenu(-1);
}

void reset() {
  // reset all tracker variables
  score = 0;
  GENERATION = 0;
  CURR_TICK = 0;

  for(int i = 0; i < producersX.length; i++){
    producersX[i] = null;
    producersY[i] = null;
  }

  for(int i = 0; i < consumersSAT.length; i++){
    consumersSAT[i] = null;
  }

  currentGenConsumers = new Consumer[CONSUMERS];
  consPtr = 0;
  currentGenProducers = new Producer[PRODUCERS];
  prdsPtr = 0;

  setMenu(100);
}

boolean is_true(boolean[] arr){
  for(int ob : arr) {
    if(ob == false) {
      return false;
    }
  }
  return true;
}

// ==================================================================================



void increment_generation(){
  GENERATION++;
  CURR_TICK = 0;

  // ----------- CONSUMER

  // println("inside incr_gen1");
  int minWealth = 10000000;
  int maxWealth = -10000000;

  int worstCons = -1;
  int bestCons = -1;

  float tempW = 0;
  float consumerWealthTotal = 0;
  float producerWealthTotal = 0;

  // println("inside incr_gen2");
  for(int i = 0; i < currentGenConsumers.length; i++){
    if(currentGenConsumers[i] != null){
      // get best and worst
      tempW = currentGenConsumers[i].total_wealth();
      println("consumer loop: " + tempW);
      consumerWealthTotal += tempW;
      // println(i + " " + tempW);
      if(tempW < minWealth){
        minWealth = tempW;
        worstCons = i;
      }
      if(tempW > maxWealth){
        maxWealth = tempW;
        bestCons = i;
      }

      // reset position
      currentGenConsumers[i].reset_for_next_gen();
    }
  }
  // println("inside incr_gen3");
  int UUID;
  if(worstCons != bestCons){
    // replace worst consumer
    int [] colors = currentGenConsumers[bestCons].get_colors();
    UUID = currentGenConsumers[worstCons].UUID;
    currentGenConsumers[worstCons] = new Consumer(UUID, currentGenConsumers[bestCons].get_reservationPrice(), currentGenConsumers[bestCons].get_wealth(), currentGenConsumers[bestCons].get_risk(), currentGenConsumers[bestCons].get_speed()[0], currentGenConsumers[bestCons].get_speed()[1], currentGenConsumers[bestCons].get_sense(), colors[0], colors[1], colors[2]);
  } else if(worstCons == bestCons) {
    // replace random person
    UUID = random(cons);
    currentGenConsumers[UUID] = new Consumer(UUID);
  }


  // ------------- PRODUCER 
  for(int i = 0; i < currentGenProducers.length; i++){
    if(currentGenProducers[i] != null){
      producersX[i] = currentGenProducers[i].x;
      producersY[i] = currentGenProducers[i].y;

      producerWealthTotal += currentGenProducers[i].total_wealth();
    }
  }

  consWealthHistory.add(consumerWealthTotal);
  prodWealthHistory.add(producerWealthTotal);


  println("Best : " + bestCons);
  println("Worst : " + worstCons);
  // println(consWealthHistory[0] + " " + prodWealthHistory[0]);
  println("");

}



// ================================================================================================================================
// -------------------------------------------------------- MOUSE ACTION --------------------------------------------------------
void mouseReleased() {
  float mX = mouseX/windowSizeMultiplier;
  float mY = mouseY/windowSizeMultiplier;
  if (menu == 100 && abs(mX-(windowWidth/2)) <= 200 && abs(mY-400) <= 50) {
    setMenu(200); // goto GAME
  } else if (menu == 100 && abs(mX-(windowWidth/2)) <= 200 && abs(mY-550) <= 50) {
    setMenu(101); // goto INSTRUCTIONS
  } else if (menu == 100 && abs(mX-(windowWidth/2)) <= 200 && abs(mY-700) <= 50) {
    setMenu(102); // goto CREDITS
  } else if ((menu == 102 || menu == 101) && abs(mX-(windowWidth/2)) <= 200 && abs(mY-550) <= 50) {
    setMenu(100); // goto MAIN MENU
  } else if (menu == -1 && abs(mX-(windowWidth/2)) <= 300 && abs(mY-400) <= 100) {
    reset();
  } else if (menu == 200 && abs(mX-210) <= 200 && abs(mY-60) <= 50) {
    // -------------------------------- ADD CONSUMER (1st Generation)
    if(consPtr > CONSUMERS){consPtr = 0;}
    currentGenConsumers[consPtr] = new Consumer(consPtr);
    // currentGenConsumers[consPtr].display();
    consPtr++;

    if(cons <= 10){
      cons++;
    }

    // println("Consumer Added!");
    draw();
  } else if (menu == 200 && abs(mX-(windowWidth-210)) <= 200 && abs(mY-60) <= 50) {
    // -------------------------------- ADD PRODUCER
    if(prdsPtr > PRODUCERS){prdsPtr = 0;}

    currentGenProducers[prdsPtr] = new Producer(prdsPtr);
    producersX[prdsPtr] = currentGenProducers[prdsPtr].x;
    producersY[prdsPtr] = currentGenProducers[prdsPtr].y;
    prdsPtr++;

    if(prds <= 10){
      prds++;
    }

    // println("Producer Added!");
    draw();
  } else if (menu == 200 && abs(mX-(windowWidth/2)) <= 200 && abs(mY-60) <= 50) {
    // -------------------------------- SIMULATE
    setMenu(201);
  } else if (menu == 201 && abs(mX-(windowWidth/2)) <= 200 && abs(mY-60) <= 50) {
    // -------------------------------- END SIMULATION (KILL)
    for(int i = 0; i < currentGenConsumers.length; i++){
      if(currentGenConsumers[i] != null){
        currentGenConsumers[i].stop();
      }
    }
    reset();
  } else if (menu == 202 && abs(mX-(windowWidth-210)) <= 200 && abs(mY-60) <= 50) {
    // -------------------------------- NEXT GENERATION
    setMenu(200);
  }
}
// -------------------------------------------------------- MOUSE ACTION --------------------------------------------------------
// ================================================================================================================================


// ================ SETUP ================
void setup() {
  frameRate(FRAMES);
  randomSeed(SEED);
  noSmooth();
  size(windowWidth, windowHeight, P3D);
  ellipseMode(CENTER);
  
  screenImage = createGraphics(1920, 1080);

  for(int i = 0; i < producersX.length; i++){
    producersX[i] = null;
    producersY[i] = null;
  }

  for(int i = 0; i < consumersSAT.length; i++){
    consumersSAT[i] = null;
  }
  
  font = loadFont("Oswald-Regular.ttf", 96); 
  textFont(font);
  textAlign(CENTER);
  scale(windowSizeMultiplier);
  mainMenuPNG = loadImage("img/mainmenu.jpg");
  simBG = loadImage("img/bg.png");
  producerPNG = loadImage("img/producer.png");
  consumerPNG = loadImage("img/consumer.png");
  consumer_rightPNG = loadImage("img/consumer_right.png");
  consumer_leftPNG = loadImage("img/consumer_left.png");

  mainMenuPNG.filter(BLUR, 6);
  // simBG.resize(windowWidth, windowHeight);
}


// ================ DRAW ================
// MAIN MENU OPTIONS  = 1xx
// GAME SCREENS       = 2xx
// END GAME SCREEN    = -1
// ======================================
void draw() {
  // println(menu);
  if (menu == 100) {
    // MAIN MENU
    image(mainMenuPNG,0,0);
    stroke(220);
    noFill();
    strokeWeight(20);
    rect(0, 0, windowWidth-1, windowHeight-1);

    fill(100, 200, 100);
    noStroke();
    rect(windowWidth/2-200, 350, 400, 100);  // rect(x, y, w, h)
    rect(windowWidth/2-200, 500, 400, 100);
    rect(windowWidth/2-200, 650, 400, 100);
    fill(255);
    text("MARKETS", windowWidth/2, 200);
    textFont(font, 40);
    text("START", windowWidth/2, 410);
    text("INSTRUCTIONS", windowWidth/2, 565);
    text("CREDITS", windowWidth/2, 710);
    textFont(font, 96);
  } else if (menu == 101) {
    // INSTRUCTIONS
    background(34, 47, 62);
    fill(100, 200, 100);
    noStroke();
    rect(windowWidth/2-200, 500, 400, 100);
    fill(255);
    text("MARKETS", windowWidth/2, 100);
    textFont(font, 40);
    text("Welcome to Markets!", windowWidth/2, 225);
    text("This game is meant to simulate a real-time supply demand model\nwith variable inputs and user modified situations.\n\nPlay around and discover how to manipulate\nthe markets to come out on top!", windowWidth/2, 275);
    text("Main Menu", windowWidth/2, 565);
    textFont(font, 96);
  } else if (menu == 102) {
    // CREDITS
    background(34, 47, 62);
    fill(100, 200, 100);
    noStroke();
    rect(windowWidth/2-200, 500, 400, 100);
    fill(255);
    text("MARKETS", windowWidth/2, 100);
    textFont(font, 40);
    text("Author: Soukarya Ghosh\nContact: sg4fz@virginia.edu", windowWidth/2, 265);
    text("Thanks for playing! :)", windowWidth/2, 415);
    text("Main Menu", windowWidth/2, 565);
    textFont(font, 96);
  } else if (menu == 200) {
    // MAIN GAME SCREEN - TWEAKING
    // background(#f7d794);
    background(simBG);
    fill(100, 200, 100);
    noStroke();
    rect(10, 10, 400, 100);
    rect(windowWidth/2-200, 10, 400, 100);
    rect(windowWidth-410, 10, 400, 100);
    textFont(font, 40);
    fill(0);
    text("Add Consumer", 210, 75);
    text("Simulate", windowWidth/2, 75)
    text("Add Producer", windowWidth-210, 75);
    
    textFont(font, 12);

    for(int i = 0; i < currentGenProducers.length; i++){
      if(currentGenProducers[i] != null){
        currentGenProducers[i].display(this);
      }
    }

    for(int i = 0; i < currentGenConsumers.length; i++){
      if(currentGenConsumers[i] != null){
        currentGenConsumers[i].display(this);
      }
    }

    textFont(font, 96);

  } else if (menu == 201) {
    // MAIN GAME SCREEN - SIMULATING
    // background(#f7d794);
    background(simBG);
    fill(200, 100, 100);
    noStroke();
    rect(windowWidth/2-200, 10, 400, 100);
    textFont(font, 40);
    fill(0);
    text("KILL", windowWidth/2, 75)
    fill(255),
    text("Generation " + GENERATION, 150, 50);
    text("Timer: " + int(CURR_TICK/60) + "s", windowWidth-100, 50);

    CURR_TICK++;

    textFont(font, 12);
    for(int i = 0; i < currentGenProducers.length; i++){
      if(currentGenProducers[i] != null){
        currentGenProducers[i].display(this);
      }
    }

    for(int i = 0; i < currentGenConsumers.length; i++){
      if(currentGenConsumers[i] != null){
        currentGenConsumers[i].display(this);
        currentGenConsumers[i].move();
      }
    }

    // IF out of time OR all consumers are satisfied THEN go to generation stats screen
    if(CURR_TICK >= GENERATION_TIME || is_true(consumersSAT)){
      increment_generation();
      // println("going to stats");
      setMenu(202);
    }

  } else if (menu == 202) {
    // MAIN GAME SCREEN - END OF GENERATION X STATISTICS

    background(#f7d794);
    fill(100, 200, 100);
    noStroke();
    rect(windowWidth-410, 10, 400, 100);
    textFont(font, 40);
    fill(0);
    text("Next Gen", windowWidth-210, 75);
    text("Generation " + (GENERATION-1), 150, 50);

    textFont(font, 30);
    for(int i = 0; i < consWealthHistory.size(); i++){
      text("Consumer Total (Generation " + i + "): " + int(consWealthHistory.get(i)), windowWidth/2-300, 100*(i+1)+50);
      text("Producer Total (Generation " + i + "): " + int(prodWealthHistory.get(i)), windowWidth/2+300, 100*(i+1)+50);
    }

  } else if (menu == -1) {
    // GAME OVER STATE
    background(255);
    fill(55, 250, 50);
    noStroke();
    rect(windowWidth/2-300, 300, 600, 200);  // rect(x, y, w, h)
    fill(0);
    text("GAME OVER", windowWidth/2, 200);
    text("Main Menu", windowWidth/2, 430);
  }

}
