


local function space()
  return {
    {
        property = "pressure",
        min = 0,
        max = 0,
    },
    {
        property = "gravity",
        min = 0,
        max = 0,
    },
  }
end
local function planet()
  return{

    {
        property = "pressure",
        min = 10,
        max = 2000,
    },
    {
        property = "gravity",
        min = 10,
        max = 2000,
    },
  }
end

--[[
  {
    property = "pressure", -- Свойство поверхности (атмосферное давление)
    min = 10,              -- Минимальное значение (например, как на Наувисе)
    max = 2000             -- Максимальное значение (не даст построить в вакууме космоса)
  },
  {
    property = "gravity",  -- Свойство поверхности (гравитация)
    min = 0.5,             -- Нельзя построить на планетах со слишком низкой гравитацией
  },
  {
    property = "magnetic-field", -- Магнитное поле (например, для Фульгоры)
    max = 50,              -- Запретит постройку в зонах с сильнейшими бурями
  }
]]

return {
  space = space,
  planet = planet,
}
