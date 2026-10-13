import java.util.*;
import java.net.http.*;
public class SoloTest {
 static void ok(boolean b,String m){if(!b)throw new AssertionError(m);}
 static void no(Runnable r){try{r.run();throw new AssertionError("accepted invalid action");}catch(IllegalArgumentException expected){}}
 public static void main(String[] args)throws Exception{
  if(args.length>0){fixture();return;}
  Chess2.Game original=new Chess2.Game(42),copy=Chess2.Bot.copy(original);
  copy.pieces.get(0).shield=true;copy.players[0].money+=99;copy.players[0].hand.clear();
  ok(!original.pieces.get(0).shield&&original.players[0].money!=copy.players[0].money,"copy isolation");
  for(Chess2.Skill skill:Chess2.Skill.values()){
   Chess2.Game g=Chess2.emptyGame();g.add(3,1,0,0);g.add(0,0,0,3);g.turn=1;
   long start=System.currentTimeMillis();Map<String,String> a=new Chess2.Bot(skill,42).choose(g,false);
   g.action(a);ok(g.valid(),"legal "+skill);ok(System.currentTimeMillis()-start<8000,"bounded "+skill);
   if(skill!=Chess2.Skill.EASY)ok(g.winner==1,"sees winning capture "+skill);
   try(Chess2.Session s=new Chess2.Session(new Chess2.Game(42),true,0,skill,false,42)){
    s.action(0,Chess2.args("op","pass","revision","0"));
    no(()->s.action(1,Chess2.args("op","pass","revision","1")));
    long deadline=System.currentTimeMillis()+10000;
    while(s.g.turn==1&&System.currentTimeMillis()<deadline){s.tick();Thread.sleep(30);}
    ok(s.g.turn==0&&s.g.ply==2&&s.g.valid(),"async reply "+skill);
   }
   System.out.println("PASS "+skill+": valid tactical choice and asynchronous reply");
  }
  Chess2.Campaign c=new Chess2.Campaign(123),same=new Chess2.Campaign(123);
  Chess2.Game g=c.first(), twin=same.first();
  ok(g.valid()&&g.pieces.size()==9,"starting army");
  ok(Chess2.json(new Chess2.Session(g,false,0).state(0)).equals(Chess2.json(new Chess2.Session(twin,false,0).state(0))),"seed repeatability");
  g.pieces.get(0).boots=true;
  for(int floor=1;floor<=6;floor++){
   ok(c.floor==floor&&g.valid()&&g.campaignBattle,"encounter "+floor);
   g.pieces.removeIf(p->p.color==1);g.winner=0;c.observe(g);
   if(floor==6){ok(c.phase.equals("victory"),"final win");no(()->c.route(twin,"supply"));break;}
   ok(c.phase.equals("reward")&&c.rewards.size()==3,"three rewards");
   no(()->c.reward(twin,"invented"));
   String reward=c.rewards.get(0).id();c.reward(g,reward);no(()->c.reward(twin,reward));
   int survivors=(int)g.pieces.stream().filter(p->p.color==0).count();
   g=c.route(g,(floor+1)%3==0?"boss":"supply");
   ok(g.pieces.stream().filter(p->p.color==0).count()==survivors,"survivors persist");
   ok(g.pieces.get(0).boots,"equipment persists");
  }
  Chess2.Campaign loss=new Chess2.Campaign(1);Chess2.Game lost=loss.first();lost.winner=1;loss.observe(lost);ok(loss.phase.equals("defeat"),"loss");no(()->loss.route(lost,"supply"));
  Chess2.Campaign fixed=new Chess2.Campaign(2);Chess2.Game board=fixed.first();board.ply=37;board.end();ok(board.size==8,"campaign no expansion");
  try(Chess2.Session s=new Chess2.Session(new Chess2.Game(1),true,0,Chess2.Skill.NORMAL,true,1)){
   s.start("127.0.0.1",0);var response=Chess2.request(HttpClient.newHttpClient(),"http://127.0.0.1:"+s.port(),"/state",s.tokens[1],null);
   ok(response.statusCode()==403,"bot seat private");
  }
  System.out.println("PASS campaign: seeded armies, all six battles, rewards, replay protection, survivors, gear, bosses, defeat and solo seat authorization");
 }
 static void fixture()throws Exception{
  Chess2.Session s=new Chess2.Session(new Chess2.Game(42),true,0,Chess2.Skill.NORMAL,true,42);
  s.g.pieces.clear();s.g.tiles.clear();s.g.add(3,0,0,7);s.g.add(0,1,0,5);
  s.start("127.0.0.1",8081);
  System.out.println("http://127.0.0.1:8081/#"+s.tokens[0]);
  Runtime.getRuntime().addShutdownHook(new Thread(s::close));
  Thread.currentThread().join();
 }
}

