namespace FantasyFarm.Characters;

public enum StateId
{
    Idle,
    Walk,
    Tool,
    Water,
    Peck,
    Rest,
    Sleep
}
public interface IState
{
    void Enter();

    void Exit();

    void Update(double delta);

    void PhysicsUpdate(double delta);
}
public interface ICharacterController
{
    CharacterBase Actor
    {
        get;
    }
}
