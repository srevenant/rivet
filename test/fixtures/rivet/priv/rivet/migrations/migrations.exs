[
  [
    include: "pinky",
    prefix: 400
  ],
  [
    external: :test_app,
    migrations: [
      [include: "yoink", prefix: 300]
    ]
  ]
]
